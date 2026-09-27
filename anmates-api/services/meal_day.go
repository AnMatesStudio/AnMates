package services

import (
	"context"
	"errors"
	"hash/fnv"
	"sort"
	"strings"
	"time"
	"unicode"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// MealStatuses are the day-of statuses a member can set for a confirmed meal.
var MealStatuses = map[string]struct{}{"on_my_way": {}, "running_late_10": {}, "running_late_20": {}, "arrived": {}}

// ErrNotNow: no confirmed booking, or it is not between 3 h before and 2 h after its time.
var ErrNotNow = errors.New("no confirmed meal around now")

type MealStatusView struct {
	Mine    *string `json:"mine"`
	Partner *string `json:"partner"`
}

type Icebreaker struct {
	VI string `json:"vi"`
	EN string `json:"en"`
}

type IcebreakerSet struct {
	Prompts []Icebreaker `json:"prompts"`
	Shared  []string     `json:"shared"`
}

type MealDayService struct{ pool *pgxpool.Pool }

func NewMealDayService(pool *pgxpool.Pool) *MealDayService { return &MealDayService{pool: pool} }

// partnerOf looks up the match's two members and returns the other one's id.
func (s *MealDayService) partnerOf(ctx context.Context, matchID, userID uuid.UUID) (uuid.UUID, error) {
	var a, b uuid.UUID
	err := s.pool.QueryRow(ctx, `SELECT user_a_id, user_b_id FROM matches WHERE id = $1`, matchID).
		Scan(&a, &b)
	if err == pgx.ErrNoRows {
		return a, ErrNotFound
	}
	if err != nil {
		return a, err
	}
	if userID == a {
		return b, nil
	}
	if userID == b {
		return a, nil
	}
	return a, ErrNotFound
}

// latestConfirmedBooking returns the match's newest confirmed booking, if any.
func (s *MealDayService) latestConfirmedBooking(ctx context.Context, matchID uuid.UUID) (*uuid.UUID, time.Time, error) {
	var id uuid.UUID
	var scheduled time.Time
	err := s.pool.QueryRow(ctx, `
		SELECT id, scheduled_at FROM bookings
		WHERE match_id = $1 AND status = 'confirmed'
		ORDER BY created_at DESC LIMIT 1
	`, matchID).Scan(&id, &scheduled)
	if err == pgx.ErrNoRows {
		return nil, time.Time{}, nil
	}
	if err != nil {
		return nil, time.Time{}, err
	}
	return &id, scheduled, nil
}

// SetStatus records the member's day-of status for the latest confirmed booking
// and notifies the partner (the status value is the notification kind).
func (s *MealDayService) SetStatus(ctx context.Context, matchID, userID uuid.UUID, status string) error {
	if _, ok := MealStatuses[status]; !ok {
		return ErrNotFound
	}
	partner, err := s.partnerOf(ctx, matchID, userID)
	if err != nil {
		return err
	}
	bookingID, scheduled, err := s.latestConfirmedBooking(ctx, matchID)
	if err != nil {
		return err
	}
	if bookingID == nil {
		return ErrNotNow
	}
	now := time.Now()
	if now.Before(scheduled.Add(-3 * time.Hour)) || now.After(scheduled.Add(2 * time.Hour)) {
		return ErrNotNow
	}
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	if _, err = tx.Exec(ctx, `
		INSERT INTO meal_status (booking_id, user_id, status)
		VALUES ($1, $2, $3)
		ON CONFLICT (booking_id, user_id) DO UPDATE SET status = EXCLUDED.status, updated_at = now()
	`, *bookingID, userID, status); err != nil {
		return err
	}
	if _, err = tx.Exec(ctx, `
		INSERT INTO notifications (user_id, kind, match_id, actor_id) VALUES ($1, $2, $3, $4)
	`, partner, status, matchID, userID); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

// Status returns the day-of status of both members for the latest confirmed booking.
func (s *MealDayService) Status(ctx context.Context, matchID, userID uuid.UUID) (*MealStatusView, error) {
	if _, err := s.partnerOf(ctx, matchID, userID); err != nil {
		return nil, err
	}
	bookingID, _, err := s.latestConfirmedBooking(ctx, matchID)
	if err != nil {
		return nil, err
	}
	view := &MealStatusView{}
	if bookingID == nil {
		return view, nil
	}
	rows, err := s.pool.Query(ctx, `SELECT user_id, status FROM meal_status WHERE booking_id = $1`, *bookingID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var uid uuid.UUID
		var st string
		if err := rows.Scan(&uid, &st); err != nil {
			return nil, err
		}
		if uid == userID {
			view.Mine = &st
		} else {
			view.Partner = &st
		}
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return view, nil
}

// categoryNames maps wish-list category codes to Vietnamese dish names ("other" drops).
var categoryNames = map[string]string{
	"pho": "phở", "com": "cơm", "bun": "bún", "lau": "lẩu",
	"bbq": "đồ nướng", "cafe": "cà phê", "trang_mieng": "tráng miệng", "other": "",
}

// interestsOf collects one member's food interests: food_tags plus wish-list names and categories.
func (s *MealDayService) interestsOf(ctx context.Context, uid uuid.UUID) (map[string]bool, error) {
	var tags []string
	if err := s.pool.QueryRow(ctx, `SELECT COALESCE(food_tags, ARRAY[]::text[]) FROM users WHERE id = $1`, uid).
		Scan(&tags); err != nil {
		return nil, err
	}
	set := make(map[string]bool, len(tags))
	for _, t := range tags {
		if t = strings.ToLower(strings.TrimSpace(t)); t != "" {
			set[t] = true
		}
	}
	rows, err := s.pool.Query(ctx, `
		SELECT COALESCE(food_name, ''), COALESCE(food_category, '') FROM wishlists WHERE user_id = $1
	`, uid)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var name, cat string
		if err := rows.Scan(&name, &cat); err != nil {
			return nil, err
		}
		for _, v := range []string{name, cat} {
			if v = strings.ToLower(strings.TrimSpace(v)); v != "" {
				set[v] = true
			}
		}
	}
	return set, rows.Err()
}

// sharedFoods intersects both members' interests, maps category codes to Vietnamese
// dish names, drops "other", removes post-mapping duplicates, prefers specific names
// over bare categories, and sorts for stability.
func sharedFoods(a, b map[string]bool) []string {
	raw := make([]string, 0)
	for k := range a {
		if b[k] {
			raw = append(raw, k)
		}
	}
	sort.Strings(raw)

	type item struct{ raw, disp string }
	items := make([]item, 0, len(raw))
	seenDisp := map[string]bool{}
	for _, r := range raw {
		d := r
		if m, ok := categoryNames[r]; ok {
			if m == "" {
				continue
			}
			d = m
		}
		if seenDisp[d] {
			continue
		}
		seenDisp[d] = true
		items = append(items, item{raw: r, disp: d})
	}

	out := make([]string, 0, len(items))
	for i, it := range items {
		if _, isCat := categoryNames[it.raw]; !isCat {
			out = append(out, it.disp)
			continue
		}
		covered := false
		for j, other := range items {
			if j != i && strings.Contains(other.disp, it.disp) {
				covered = true
				break
			}
		}
		if !covered {
			out = append(out, it.disp)
		}
	}
	sort.Strings(out)
	return out
}

var foodTemplates = []struct{ vi, en string }{
	{"Hai bạn cùng thích {food} — quán {food} ruột của bạn ở đâu?", "You both love {food} — where's your go-to spot for it?"},
	{"{food} phải thế nào mới đúng điệu với bạn?", "What makes {food} just right for you?"},
	{"Lần gần nhất bạn ăn {food} là ở đâu, có đáng quay lại không?", "Where did you last have {food} — worth going back?"},
	{"Nếu chỉ được ăn {food} ở một quán cả năm, bạn chọn quán nào?", "If you could only eat {food} at one place for a year, which one?"},
}

var genericTemplates = []struct{ vi, en string }{
	{"Món nào bạn ăn mỗi tuần cũng không chán?", "Which dish could you eat every week without getting bored?"},
	{"Quán nào bạn hay dẫn bạn bè tới nhất?", "Which place do you take friends to most?"},
	{"Món ngon nhất bạn từng ăn ở một quán vỉa hè là gì?", "What's the best thing you've eaten at a street stall?"},
	{"Bạn thích quán đông vui hay quán yên tĩnh?", "Lively places or quiet ones?"},
}

// buildIcebreakers picks 3 deterministic prompts (seeded by the match id) — food
// templates cycling through the shared foods when there is at least one, otherwise
// generic templates.
func buildIcebreakers(matchID uuid.UUID, shared []string) []Icebreaker {
	h := fnv.New32a()
	_, _ = h.Write([]byte(matchID.String()))
	seed := int(h.Sum32())

	out := make([]Icebreaker, 0, 3)
	if len(shared) == 0 {
		start := seed % len(genericTemplates)
		for i := 0; i < 3; i++ {
			t := genericTemplates[(start+i)%len(genericTemplates)]
			out = append(out, Icebreaker{VI: t.vi, EN: t.en})
		}
		return out
	}
	start := seed % len(foodTemplates)
	for i := 0; i < 3; i++ {
		t := foodTemplates[(start+i)%len(foodTemplates)]
		food := shared[i%len(shared)]
		out = append(out, Icebreaker{VI: renderFood(t.vi, food), EN: renderFood(t.en, food)})
	}
	return out
}

// renderFood substitutes {food}, capitalising it when it starts the sentence.
func renderFood(tpl, food string) string {
	sub := food
	if strings.HasPrefix(tpl, "{food}") {
		if r := []rune(food); len(r) > 0 {
			r[0] = unicode.ToUpper(r[0])
			sub = string(r)
		}
	}
	return strings.ReplaceAll(tpl, "{food}", sub)
}

// Icebreakers returns the shared food interests of the two members plus 3 prompts.
func (s *MealDayService) Icebreakers(ctx context.Context, matchID, userID uuid.UUID) (*IcebreakerSet, error) {
	partner, err := s.partnerOf(ctx, matchID, userID)
	if err != nil {
		return nil, err
	}
	a, err := s.interestsOf(ctx, userID)
	if err != nil {
		return nil, err
	}
	b, err := s.interestsOf(ctx, partner)
	if err != nil {
		return nil, err
	}
	shared := sharedFoods(a, b)
	return &IcebreakerSet{Prompts: buildIcebreakers(matchID, shared), Shared: shared}, nil
}
