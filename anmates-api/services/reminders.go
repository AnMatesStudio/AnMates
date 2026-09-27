package services

import (
	"context"
	"log/slog"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// ReminderService sends each confirmed meal two reminders to both people: ~24 h before (only when the booking was
// confirmed at least 20 h ahead — a meal confirmed this afternoon needs no "tomorrow" nudge) and ~2 h before.
// Each UPDATE ... RETURNING claims the rows it reminds, so several API replicas never send one twice.
type ReminderService struct {
	pool *pgxpool.Pool
	log  *slog.Logger
}

func NewReminderService(pool *pgxpool.Pool, log *slog.Logger) *ReminderService {
	return &ReminderService{pool: pool, log: log}
}

// RunDue sends every reminder that is due now; returns how many notifications it created.
func (r *ReminderService) RunDue(ctx context.Context) (int, error) {
	sent24h, err := r.pool.Exec(ctx, `
WITH due AS (
  UPDATE bookings SET reminded_24h_at = now()
  WHERE status = 'confirmed' AND reminded_24h_at IS NULL
    AND scheduled_at >  now() + interval '2 hours'
    AND scheduled_at <= now() + interval '24 hours'
    AND updated_at   <= scheduled_at - interval '20 hours'
  RETURNING match_id
)
INSERT INTO notifications (user_id, kind, match_id, actor_id)
SELECT m.user_a_id, 'booking_reminder_24h', m.id, m.user_b_id FROM due JOIN matches m ON m.id = due.match_id
UNION ALL
SELECT m.user_b_id, 'booking_reminder_24h', m.id, m.user_a_id FROM due JOIN matches m ON m.id = due.match_id
`)
	if err != nil {
		return 0, err
	}
	n := int(sent24h.RowsAffected())

	sent2h, err := r.pool.Exec(ctx, `
WITH due AS (
  UPDATE bookings SET reminded_2h_at = now()
  WHERE status = 'confirmed' AND reminded_2h_at IS NULL
    AND scheduled_at >  now()
    AND scheduled_at <= now() + interval '2 hours'
  RETURNING match_id
)
INSERT INTO notifications (user_id, kind, match_id, actor_id)
SELECT m.user_a_id, 'booking_reminder_2h', m.id, m.user_b_id FROM due JOIN matches m ON m.id = due.match_id
UNION ALL
SELECT m.user_b_id, 'booking_reminder_2h', m.id, m.user_a_id FROM due JOIN matches m ON m.id = due.match_id
`)
	if err != nil {
		return n, err
	}
	return n + int(sent2h.RowsAffected()), nil
}

// Run calls RunDue every interval until ctx is done (errors are logged, never fatal).
func (r *ReminderService) Run(ctx context.Context, interval time.Duration) {
	t := time.NewTicker(interval)
	defer t.Stop()
	runOnce := func() {
		runCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()
		n, err := r.RunDue(runCtx)
		if err != nil {
			r.log.Warn("reminders: run due", "err", err)
			return
		}
		if n > 0 {
			r.log.Info("booking reminders sent", "count", n)
		}
	}
	runOnce()
	for ctx.Err() == nil {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
		}
		runOnce()
	}
}
