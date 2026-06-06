package services

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"sync"
	"time"

	"github.com/anmates/api/models"
	wsx "github.com/anmates/api/ws"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// warmTTL bounds how long a prefetched suggestion stays usable. Web-search results
// age slowly, but locations/mood could change, so we re-fetch after this window.
const warmTTL = 10 * time.Minute

// ConciergeConfig is the runtime tuning for the AI Concierge.
type ConciergeConfig struct {
	AIUserID       uuid.UUID
	TriggerPoints  int
	WarmPoints     int // < TriggerPoints: prefetch+cache the card here so the fire is instant. 0 disables.
	CandidateLim   int
	RadiusM        int
	MaxSeparationM int // 0 disables the "too far apart" guard
	BudgetMin      int
	BudgetMax      int
	Model          string
}

// VenueProvider supplies ready-to-render venue picks around a midpoint. It is the
// pluggable seam between "where do venues come from" and the concierge flow:
//   - WebSearchProvider  → calls the ai-venue-search Python service (MCP web-search)
//   - DBLLMVenueProvider → legacy restaurants table + LLM ranking (fallback)
// The provider owns the anti-hallucination policy (the DB path validates by id;
// the web-search path trusts the search results).
type VenueProvider interface {
	// Suggest returns an intro line + up to `limit` picks for `mid`. costTokens is
	// best-effort (0 when unknown). An error means "no card this time".
	Suggest(ctx context.Context, mid LatLng, mood []string, budgetMin, budgetMax, radiusM, limit int) (intro string, picks []cardPick, costTokens int, err error)
}

// ConciergeService fires the AI venue suggestion when a match's Vibe crosses the
// threshold. See docs/specs/ai-concierge-chat-spec.md.
type ConciergeService struct {
	pool     *pgxpool.Pool
	provider VenueProvider
	hub      wsx.HubI
	cfg      ConciergeConfig
	log      *slog.Logger

	// Pre-warm cache: the (slow) provider call is started when Vibe enters the warm
	// band below the trigger, and the result parked here so the eventual fire is instant.
	mu      sync.Mutex
	warm    map[uuid.UUID]warmEntry // matchID → prefetched suggestion (consumed on fire)
	warming map[uuid.UUID]struct{}  // matches with a prewarm in flight (dedupe guard)
}

// warmEntry is a prefetched suggestion waiting for its match to cross the trigger.
type warmEntry struct {
	mid   LatLng
	intro string
	picks []cardPick
	cost  int
	at    time.Time
}

func NewConciergeService(pool *pgxpool.Pool, provider VenueProvider, hub wsx.HubI, cfg ConciergeConfig, log *slog.Logger) *ConciergeService {
	if log == nil {
		log = slog.Default()
	}
	return &ConciergeService{
		pool: pool, provider: provider, hub: hub, cfg: cfg, log: log,
		warm:    make(map[uuid.UUID]warmEntry),
		warming: make(map[uuid.UUID]struct{}),
	}
}

// crossedThreshold reports whether points went from below to at/above the threshold.
func crossedThreshold(before, after, threshold int) bool {
	return before < threshold && after >= threshold
}

// fireAction is what MaybeFire decided to do for one points update.
type fireAction int

const (
	actNone fireAction = iota
	actWarm            // entered the warm band → prefetch + cache in the background
	actFire            // crossed the trigger → post the card (uses the cache if warm)
)

// decideAction is the pure trigger-decision logic (unit-tested without a DB). A single
// update can only do one thing: a jump straight past the trigger fires immediately
// (no warm), while entering [WarmPoints, TriggerPoints) prefetches.
func decideAction(before, after, warmPoints, triggerPoints int) fireAction {
	if crossedThreshold(before, after, triggerPoints) {
		return actFire
	}
	if warmPoints > 0 && warmPoints < triggerPoints &&
		crossedThreshold(before, after, warmPoints) && after < triggerPoints {
		return actWarm
	}
	return actNone
}

// MaybeFire is called after each message's points update. It returns immediately;
// the actual work runs in a goroutine so user message latency is unaffected.
func (s *ConciergeService) MaybeFire(matchID uuid.UUID, before, after int) {
	switch decideAction(before, after, s.cfg.WarmPoints, s.cfg.TriggerPoints) {
	case actFire:
		go s.fire(matchID)
	case actWarm:
		go s.prewarm(matchID)
	}
}

// prewarm runs the expensive provider call early and parks the result in the cache.
// It is best-effort and silent: failures just mean fire() will compute fresh later.
// One prewarm per match at a time; skipped if already cached fresh or already fired.
func (s *ConciergeService) prewarm(matchID uuid.UUID) {
	s.mu.Lock()
	if _, inflight := s.warming[matchID]; inflight {
		s.mu.Unlock()
		return
	}
	if e, ok := s.warm[matchID]; ok && time.Since(e.at) < warmTTL {
		s.mu.Unlock()
		return
	}
	s.warming[matchID] = struct{}{}
	s.mu.Unlock()
	defer func() {
		s.mu.Lock()
		delete(s.warming, matchID)
		s.mu.Unlock()
	}()

	ctx, cancel := context.WithTimeout(context.Background(), 75*time.Second)
	defer cancel()

	if s.alreadyFired(ctx, matchID) {
		return
	}
	mid, intro, picks, cost, status := s.compute(ctx, matchID)
	if status != "ok" {
		return // not ready (no locations yet / provider miss) — try again at fire time
	}
	s.mu.Lock()
	s.warm[matchID] = warmEntry{mid: mid, intro: intro, picks: picks, cost: cost, at: time.Now()}
	s.mu.Unlock()
	s.log.Info("concierge prewarmed", "match", matchID, "picks", len(picks))
}

func (s *ConciergeService) fire(matchID uuid.UUID) {
	ctx, cancel := context.WithTimeout(context.Background(), 75*time.Second)
	defer cancel()

	// Idempotency pre-check (the unique index is the real guarantee on races).
	if s.alreadyFired(ctx, matchID) {
		return
	}

	// Fast path: a prewarm already fetched this card → post it with zero search latency.
	mid, intro, picks, costTokens, ok := s.takeWarm(matchID)
	if !ok {
		var status string
		mid, intro, picks, costTokens, status = s.compute(ctx, matchID)
		if status != "ok" {
			// "too far apart" carries a user-facing notice in intro — post it so the
			// silence is explained; other skip/error statuses stay silent telemetry.
			if status == "skipped_too_far" && intro != "" {
				s.postNotice(ctx, matchID, intro)
			}
			s.recordRun(ctx, matchID, status, uuid.Nil, costTokens)
			return
		}
	}
	if len(picks) > 3 {
		picks = picks[:3]
	}

	content := CardContent{Intro: fallbackIntro(intro), Midpoint: mid, Picks: picks}
	body, _ := json.Marshal(content)

	saved, err := s.persist(ctx, matchID, string(body), costTokens)
	if err != nil {
		// Lost the idempotency race (unique index) or a DB error — drop silently.
		return
	}

	payload, _ := json.Marshal(saved)
	// senderID = AI user, which matches neither member, so BOTH users receive it.
	s.hub.Broadcast(matchID, s.cfg.AIUserID, wsx.Envelope{Type: "message", Payload: payload})
}

// compute does the expensive, side-effect-free part shared by prewarm and fire:
// resolve members → both locations → mood → provider.Suggest. It never persists or
// broadcasts. status is one of "ok" | "error" | "skipped_preconds" | "skipped_too_far"
// (so fire can record the run with the right granularity; prewarm just checks for "ok").
func (s *ConciergeService) compute(ctx context.Context, matchID uuid.UUID) (mid LatLng, intro string, picks []cardPick, cost int, status string) {
	var aID, bID uuid.UUID
	if err := s.pool.QueryRow(ctx,
		`SELECT user_a_id, user_b_id FROM matches WHERE id=$1`, matchID).Scan(&aID, &bID); err != nil {
		return LatLng{}, "", nil, 0, "error"
	}

	locA, okA := s.userLocation(ctx, aID)
	locB, okB := s.userLocation(ctx, bID)
	if !okA || !okB {
		return LatLng{}, "", nil, 0, "skipped_preconds"
	}
	mid = Midpoint(locA, locB)

	// Guard: if the two users are far apart the midpoint lands between cities and a
	// "meet in the middle" meal is impractical. Skip the search and let fire() post a
	// friendly notice (the intro slot carries the message) instead of a bad card.
	// The user can still re-anchor near one side via the on-demand SuggestForUser path.
	if sep := HaversineM(locA, locB); s.cfg.MaxSeparationM > 0 && sep > float64(s.cfg.MaxSeparationM) {
		return mid, tooFarNotice(sep), nil, 0, "skipped_too_far"
	}

	intro, picks, cost, err := s.suggestAround(ctx, mid, aID, bID)
	if err != nil {
		s.log.Warn("concierge provider failed", "match", matchID, "err", err)
		return mid, "", nil, 0, "error"
	}
	if len(picks) == 0 {
		return mid, "", nil, cost, "skipped_preconds"
	}
	return mid, intro, picks, cost, "ok"
}

// suggestAround runs the taste lookup + provider search at a given search center.
// Shared by the auto-fire (midpoint) and the on-demand re-anchor endpoint.
func (s *ConciergeService) suggestAround(ctx context.Context, center LatLng, aID, bID uuid.UUID) (string, []cardPick, int, error) {
	mood := s.moodTags(ctx, aID, bID)
	return s.provider.Suggest(ctx, center, mood, s.cfg.BudgetMin, s.cfg.BudgetMax, s.cfg.RadiusM, s.cfg.CandidateLim)
}

// Anchor errors surfaced to the HTTP layer for the on-demand suggest endpoint.
var (
	ErrBadAnchor  = errors.New("invalid anchor")
	ErrNoLocation = errors.New("required location missing")
)

// SuggestForUser re-runs the venue suggestion centered on a chosen anchor, from the
// requester's perspective. anchor ∈ {"", "midpoint", "me", "mate"} — "me" centers on
// the requester's location, "mate" on the other member's, "midpoint" (default) between
// them. Distances on the card are relative to that center. It does NOT persist or
// broadcast — it's a private per-user re-roll (the user shares a pick via a normal
// chat message when they decide). requesterID must already be a verified match member.
func (s *ConciergeService) SuggestForUser(ctx context.Context, matchID, requesterID uuid.UUID, anchor string) (CardContent, error) {
	var aID, bID uuid.UUID
	if err := s.pool.QueryRow(ctx,
		`SELECT user_a_id, user_b_id FROM matches WHERE id=$1`, matchID).Scan(&aID, &bID); err != nil {
		return CardContent{}, err
	}
	locA, okA := s.userLocation(ctx, aID)
	locB, okB := s.userLocation(ctx, bID)

	center, err := resolveAnchor(anchor, requesterID, aID, bID, locA, okA, locB, okB)
	if err != nil {
		return CardContent{}, err
	}

	intro, picks, _, err := s.suggestAround(ctx, center, aID, bID)
	if err != nil {
		return CardContent{}, err
	}
	if len(picks) > 3 {
		picks = picks[:3]
	}
	return CardContent{Intro: fallbackIntro(intro), Midpoint: center, Picks: picks}, nil
}

// takeWarm returns and removes a fresh prefetched suggestion for the match, if any.
// Consume-once: a stale or absent entry yields ok=false so fire() computes fresh.
func (s *ConciergeService) takeWarm(matchID uuid.UUID) (mid LatLng, intro string, picks []cardPick, cost int, ok bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	e, present := s.warm[matchID]
	if !present || time.Since(e.at) >= warmTTL {
		return LatLng{}, "", nil, 0, false
	}
	delete(s.warm, matchID)
	return e.mid, e.intro, e.picks, e.cost, true
}

// alreadyFired reports whether a card was already posted for this match (idempotency).
func (s *ConciergeService) alreadyFired(ctx context.Context, matchID uuid.UUID) bool {
	var fired bool
	_ = s.pool.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM ai_concierge_runs WHERE match_id=$1 AND status='fired')`,
		matchID).Scan(&fired)
	return fired
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

// postNotice posts a plain-text message from the AI user (no 'fired' run, so it
// never blocks a later real card) and broadcasts it. Used for the "too far apart"
// heads-up so the user isn't left wondering why no suggestion appeared.
func (s *ConciergeService) postNotice(ctx context.Context, matchID uuid.UUID, text string) {
	var m models.Message
	if err := s.pool.QueryRow(ctx, `
		INSERT INTO messages (match_id, sender_id, content, msg_type)
		VALUES ($1, $2, $3, 'text')
		RETURNING id, match_id, sender_id, content, msg_type, created_at
	`, matchID, s.cfg.AIUserID, text).Scan(
		&m.ID, &m.MatchID, &m.SenderID, &m.Content, &m.MsgType, &m.CreatedAt); err != nil {
		s.log.Warn("concierge notice failed", "match", matchID, "err", err)
		return
	}
	payload, _ := json.Marshal(m)
	s.hub.Broadcast(matchID, s.cfg.AIUserID, wsx.Envelope{Type: "message", Payload: payload})
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
	Address      string   `json:"address,omitempty"`
	Rating       *float64 `json:"rating,omitempty"`
	PriceMin     *int     `json:"price_min,omitempty"`
	PriceMax     *int     `json:"price_max,omitempty"`
	Lat          float64  `json:"lat"`
	Lng          float64  `json:"lng"`
	DistanceM    int      `json:"distance_m"`
	Reason       string   `json:"reason"`
}

// CardContent is the JSON payload of an ai_venue_card message and the on-demand
// suggest response. Midpoint holds the search center (the midpoint or the chosen anchor).
type CardContent struct {
	Intro    string     `json:"intro"`
	Midpoint LatLng     `json:"midpoint"`
	Picks    []cardPick `json:"picks"`
}

// resolveAnchor maps an anchor mode to the search center from the requester's view.
// requester must be aID or bID (enforced upstream by the membership check).
func resolveAnchor(anchor string, requester, aID, bID uuid.UUID, locA LatLng, okA bool, locB LatLng, okB bool) (LatLng, error) {
	// "me"/"mate" pick one side; pre-resolve which physical location is which.
	meLoc, meOK := locB, okB
	mateLoc, mateOK := locA, okA
	if requester == aID {
		meLoc, meOK = locA, okA
		mateLoc, mateOK = locB, okB
	}
	switch anchor {
	case "", "midpoint":
		if !okA || !okB {
			return LatLng{}, ErrNoLocation
		}
		return Midpoint(locA, locB), nil
	case "me":
		if !meOK {
			return LatLng{}, ErrNoLocation
		}
		return meLoc, nil
	case "mate":
		if !mateOK {
			return LatLng{}, ErrNoLocation
		}
		return mateLoc, nil
	default:
		return LatLng{}, ErrBadAnchor
	}
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

// tooFarNotice builds the user-facing "you two are far apart" message, rounding the
// separation to a friendly km figure. Pure → unit-tested without a DB.
func tooFarNotice(sepM float64) string {
	km := int(sepM/1000 + 0.5)
	return fmt.Sprintf(
		"Trợ lý ĂnMates: 2 bạn đang cách nhau khoảng %d km nên mình chưa tìm được quán ở giữa hợp lý. "+
			"Khi nào 2 bạn ở gần nhau hơn, hoặc chốt khu vực của một trong hai, mình gợi ý quán liền nha!",
		km,
	)
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
