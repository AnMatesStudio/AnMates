package services

import (
	"context"
	"encoding/json"
	"log/slog"
	"time"

	"github.com/anmates/api/models"
	wsx "github.com/anmates/api/ws"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// ConciergeConfig is the runtime tuning for the AI Concierge.
type ConciergeConfig struct {
	AIUserID      uuid.UUID
	TriggerPoints int
	CandidateLim  int
	RadiusM       int
	BudgetMin     int
	BudgetMax     int
	Model         string
}

// ConciergeService fires the AI venue suggestion when a match's Vibe crosses the
// threshold. See docs/specs/ai-concierge-chat-spec.md.
type ConciergeService struct {
	pool   *pgxpool.Pool
	llm    LLMClient
	venues *VenueEngine
	hub    wsx.HubI
	cfg    ConciergeConfig
	log    *slog.Logger
}

func NewConciergeService(pool *pgxpool.Pool, llm LLMClient, venues *VenueEngine, hub wsx.HubI, cfg ConciergeConfig, log *slog.Logger) *ConciergeService {
	if log == nil {
		log = slog.Default()
	}
	return &ConciergeService{pool: pool, llm: llm, venues: venues, hub: hub, cfg: cfg, log: log}
}

// crossedThreshold reports whether points went from below to at/above the threshold.
func crossedThreshold(before, after, threshold int) bool {
	return before < threshold && after >= threshold
}

// MaybeFire is called after each message's points update. It returns immediately;
// the actual work runs in a goroutine so user message latency is unaffected.
func (s *ConciergeService) MaybeFire(matchID uuid.UUID, before, after int) {
	if !crossedThreshold(before, after, s.cfg.TriggerPoints) {
		return
	}
	go s.fire(matchID)
}

func (s *ConciergeService) fire(matchID uuid.UUID) {
	ctx, cancel := context.WithTimeout(context.Background(), 45*time.Second)
	defer cancel()

	// Idempotency pre-check (the unique index is the real guarantee on races).
	var alreadyFired bool
	_ = s.pool.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM ai_concierge_runs WHERE match_id=$1 AND status='fired')`,
		matchID).Scan(&alreadyFired)
	if alreadyFired {
		return
	}

	// Match members.
	var aID, bID uuid.UUID
	if err := s.pool.QueryRow(ctx,
		`SELECT user_a_id, user_b_id FROM matches WHERE id=$1`, matchID).Scan(&aID, &bID); err != nil {
		s.recordRun(ctx, matchID, "error", uuid.Nil, 0)
		return
	}

	// Both locations required.
	locA, okA := s.userLocation(ctx, aID)
	locB, okB := s.userLocation(ctx, bID)
	if !okA || !okB {
		s.recordRun(ctx, matchID, "skipped_preconds", uuid.Nil, 0)
		return
	}
	mid := Midpoint(locA, locB)

	mood := s.moodTags(ctx, aID, bID)

	candidates, err := s.venues.SearchCandidates(ctx, mid, s.cfg.BudgetMin, s.cfg.BudgetMax, s.cfg.RadiusM, s.cfg.CandidateLim)
	if err != nil || len(candidates) == 0 {
		s.recordRun(ctx, matchID, "skipped_preconds", uuid.Nil, 0)
		return
	}

	out, err := s.llm.Rank(ctx, ConciergeInput{
		MoodTags: mood, BudgetMin: s.cfg.BudgetMin, BudgetMax: s.cfg.BudgetMax, Candidates: candidates,
	})
	if err != nil {
		s.log.Warn("concierge llm failed", "match", matchID, "err", err)
		s.recordRun(ctx, matchID, "error", uuid.Nil, 0)
		return
	}

	picks := validatePicks(out.Picks, candidates, 3)
	if len(picks) == 0 {
		s.recordRun(ctx, matchID, "error", uuid.Nil, out.CostTokens)
		return
	}

	content := cardContent{Intro: fallbackIntro(out.Intro), Midpoint: mid, Picks: picks}
	body, _ := json.Marshal(content)

	saved, err := s.persist(ctx, matchID, string(body), out.CostTokens)
	if err != nil {
		// Lost the idempotency race (unique index) or a DB error — drop silently.
		return
	}

	payload, _ := json.Marshal(saved)
	// senderID = AI user, which matches neither member, so BOTH users receive it.
	s.hub.Broadcast(matchID, s.cfg.AIUserID, wsx.Envelope{Type: "message", Payload: payload})
}

// persist writes the AI card message + the 'fired' run row atomically. The partial
// unique index on ai_concierge_runs(status='fired') turns a concurrent double-fire
// into an error here, which we treat as "someone else already posted".
func (s *ConciergeService) persist(ctx context.Context, matchID uuid.UUID, content string, costTokens int) (*models.Message, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx) //nolint:errcheck // no-op after commit

	var m models.Message
	if err := tx.QueryRow(ctx, `
		INSERT INTO messages (match_id, sender_id, content, msg_type)
		VALUES ($1, $2, $3, 'ai_venue_card')
		RETURNING id, match_id, sender_id, content, msg_type, created_at
	`, matchID, s.cfg.AIUserID, content).Scan(
		&m.ID, &m.MatchID, &m.SenderID, &m.Content, &m.MsgType, &m.CreatedAt); err != nil {
		return nil, err
	}

	if _, err := tx.Exec(ctx, `
		INSERT INTO ai_concierge_runs (match_id, trigger, status, message_id, model, cost_tokens)
		VALUES ($1, 'vibe_70', 'fired', $2, $3, $4)
	`, matchID, m.ID, s.cfg.Model, costTokens); err != nil {
		return nil, err
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return &m, nil
}

func (s *ConciergeService) recordRun(ctx context.Context, matchID uuid.UUID, status string, msgID uuid.UUID, cost int) {
	var msgPtr *uuid.UUID
	if msgID != uuid.Nil {
		msgPtr = &msgID
	}
	_, _ = s.pool.Exec(ctx, `
		INSERT INTO ai_concierge_runs (match_id, trigger, status, message_id, model, cost_tokens)
		VALUES ($1, 'vibe_70', $2, $3, $4, $5)
	`, matchID, status, msgPtr, s.cfg.Model, cost)
}

func (s *ConciergeService) userLocation(ctx context.Context, userID uuid.UUID) (LatLng, bool) {
	var ll LatLng
	if err := s.pool.QueryRow(ctx,
		`SELECT lat, lng FROM user_locations WHERE user_id=$1`, userID).Scan(&ll.Lat, &ll.Lng); err != nil {
		return LatLng{}, false
	}
	return ll, true
}

// moodTags unions both users' food + vibe tags into a coarse taste signal.
func (s *ConciergeService) moodTags(ctx context.Context, a, b uuid.UUID) []string {
	seen := map[string]struct{}{}
	var out []string
	add := func(tags []string) {
		for _, t := range tags {
			if _, ok := seen[t]; !ok && t != "" {
				seen[t] = struct{}{}
				out = append(out, t)
			}
		}
	}
	rows, err := s.pool.Query(ctx, `SELECT food_tags, vibe_tags FROM users WHERE id = $1 OR id = $2`, a, b)
	if err != nil {
		return out
	}
	defer rows.Close()
	for rows.Next() {
		var food, vibe []string
		if err := rows.Scan(&food, &vibe); err != nil {
			continue
		}
		add(food)
		add(vibe)
	}
	return out
}

// ---- pure helpers (unit-tested without a DB) --------------------------------

type cardPick struct {
	RestaurantID string   `json:"restaurant_id"`
	Name         string   `json:"name"`
	Rating       *float64 `json:"rating,omitempty"`
	PriceMin     *int     `json:"price_min,omitempty"`
	PriceMax     *int     `json:"price_max,omitempty"`
	Lat          float64  `json:"lat"`
	Lng          float64  `json:"lng"`
	DistanceM    int      `json:"distance_m"`
	Reason       string   `json:"reason"`
}

type cardContent struct {
	Intro    string     `json:"intro"`
	Midpoint LatLng     `json:"midpoint"`
	Picks    []cardPick `json:"picks"`
}

// validatePicks enforces the anti-hallucination rule: only ids present in candidates
// survive; venue facts are copied from the DB candidate, never from the model. Caps at max.
func validatePicks(picks []Pick, candidates []Candidate, max int) []cardPick {
	byID := make(map[string]Candidate, len(candidates))
	for _, c := range candidates {
		byID[c.ID.String()] = c
	}
	out := make([]cardPick, 0, max)
	seen := map[string]struct{}{}
	for _, p := range picks {
		if len(out) >= max {
			break
		}
		c, ok := byID[p.RestaurantID]
		if !ok {
			continue // hallucinated / unknown id — drop
		}
		if _, dup := seen[p.RestaurantID]; dup {
			continue
		}
		seen[p.RestaurantID] = struct{}{}
		out = append(out, cardPick{
			RestaurantID: c.ID.String(), Name: c.Name, Rating: c.Rating,
			PriceMin: c.PriceMin, PriceMax: c.PriceMax, Lat: c.Lat, Lng: c.Lng,
			DistanceM: c.DistanceM, Reason: safeReason(p.Reason),
		})
	}
	return out
}

func fallbackIntro(s string) string {
	if s == "" {
		return "2 đứa hợp gu rồi nè! Đây là vài chỗ ngon, vừa túi tiền, nằm giữa 2 đứa:"
	}
	return clip(s, 160)
}

func clip(s string, n int) string {
	r := []rune(s)
	if len(r) <= n {
		return s
	}
	return string(r[:n])
}

// safeReason guards the model-authored reason text. Small Qwen models occasionally
// leak Chinese (CJK) characters into Vietnamese output; rather than show that to a
// user, fall back to a clean generic Vietnamese reason. Also clips length.
func safeReason(s string) string {
	if s == "" || containsCJK(s) {
		return "Gần điểm giữa, hợp gu 2 đứa"
	}
	return clip(s, 80)
}

// containsCJK reports whether s has any CJK character. Vietnamese (Latin + diacritics,
// all < U+2E80) never trips this; CJK ideographs/radicals/fullwidth punctuation do.
func containsCJK(s string) bool {
	for _, r := range s {
		if r >= 0x2E80 {
			return true
		}
	}
	return false
}
