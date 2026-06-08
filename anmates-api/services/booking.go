package services

import (
	"context"
	"errors"
	"time"

	"github.com/anmates/api/models"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Booking flow errors, mapped to HTTP codes by handlers/booking.go.
var (
	ErrNotMember    = errors.New("not a match member")
	ErrNoBooking    = errors.New("no active booking")
	ErrConfirmOwn   = errors.New("cannot confirm your own proposal")
	ErrPastSchedule = errors.New("scheduled time must be in the future")
	ErrNoVenue      = errors.New("restaurant_name required")
)

// ProposeInput is the venue + time for a First Date proposal.
type ProposeInput struct {
	RestaurantName    string
	RestaurantAddress string
	Lat               *float64
	Lng               *float64
	ScheduledAt       time.Time
}

type BookingService struct {
	pool *pgxpool.Pool
}

func NewBookingService(pool *pgxpool.Pool) *BookingService { return &BookingService{pool: pool} }

const bookingCols = `id, match_id, proposed_by, restaurant_name, restaurant_address,
	lat, lng, scheduled_at, status, created_at, updated_at`

func scanBooking(row pgx.Row) (*models.Booking, error) {
	var b models.Booking
	if err := row.Scan(&b.ID, &b.MatchID, &b.ProposedBy, &b.RestaurantName, &b.RestaurantAddress,
		&b.Lat, &b.Lng, &b.ScheduledAt, &b.Status, &b.CreatedAt, &b.UpdatedAt); err != nil {
		return nil, err
	}
	return &b, nil
}

// IsMember reports whether userID participates in matchID.
func (s *BookingService) IsMember(ctx context.Context, matchID, userID uuid.UUID) bool {
	var ok bool
	_ = s.pool.QueryRow(ctx, `
		SELECT EXISTS(SELECT 1 FROM matches
			WHERE id = $1 AND (user_a_id = $2 OR user_b_id = $2))
	`, matchID, userID).Scan(&ok)
	return ok
}

// validateProposal enforces the field rules (pure → unit-tested). now is injectable.
func validateProposal(in ProposeInput, now time.Time) error {
	if in.RestaurantName == "" {
		return ErrNoVenue
	}
	if !in.ScheduledAt.After(now) {
		return ErrPastSchedule
	}
	return nil
}

// Propose creates a First Date proposal, replacing any existing active booking for
// the match (re-proposing changes the plan). Caller must be a match member.
func (s *BookingService) Propose(ctx context.Context, matchID, userID uuid.UUID, in ProposeInput) (*models.Booking, error) {
	if !s.IsMember(ctx, matchID, userID) {
		return nil, ErrNotMember
	}
	if err := validateProposal(in, time.Now()); err != nil {
		return nil, err
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx) //nolint:errcheck // no-op after commit

	// Cancel any live booking so the partial unique index lets the new row in.
	if _, err := tx.Exec(ctx, `
		UPDATE bookings SET status='cancelled', updated_at=now()
		WHERE match_id=$1 AND status IN ('proposed','confirmed')
	`, matchID); err != nil {
		return nil, err
	}

	b, err := scanBooking(tx.QueryRow(ctx, `
		INSERT INTO bookings (match_id, proposed_by, restaurant_name, restaurant_address, lat, lng, scheduled_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7)
		RETURNING `+bookingCols,
		matchID, userID, in.RestaurantName, in.RestaurantAddress, in.Lat, in.Lng, in.ScheduledAt))
	if err != nil {
		return nil, err
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return b, nil
}

// Get returns the most recent booking for the match (any status). Caller must be a member.
func (s *BookingService) Get(ctx context.Context, matchID, userID uuid.UUID) (*models.Booking, error) {
	if !s.IsMember(ctx, matchID, userID) {
		return nil, ErrNotMember
	}
	b, err := scanBooking(s.pool.QueryRow(ctx, `
		SELECT `+bookingCols+` FROM bookings WHERE match_id=$1
		ORDER BY created_at DESC LIMIT 1`, matchID))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNoBooking
	}
	return b, err
}

// Confirm marks the active proposal confirmed. Only the member who did NOT propose
// it can confirm (mutual agreement).
func (s *BookingService) Confirm(ctx context.Context, matchID, userID uuid.UUID) (*models.Booking, error) {
	if !s.IsMember(ctx, matchID, userID) {
		return nil, ErrNotMember
	}
	var id, proposedBy uuid.UUID
	err := s.pool.QueryRow(ctx, `
		SELECT id, proposed_by FROM bookings
		WHERE match_id=$1 AND status='proposed'
		ORDER BY created_at DESC LIMIT 1`, matchID).Scan(&id, &proposedBy)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNoBooking
	}
	if err != nil {
		return nil, err
	}
	if proposedBy == userID {
		return nil, ErrConfirmOwn
	}
	return scanBooking(s.pool.QueryRow(ctx, `
		UPDATE bookings SET status='confirmed', updated_at=now()
		WHERE id=$1 RETURNING `+bookingCols, id))
}

// Cancel cancels the active (proposed|confirmed) booking. Either member may cancel.
func (s *BookingService) Cancel(ctx context.Context, matchID, userID uuid.UUID) (*models.Booking, error) {
	if !s.IsMember(ctx, matchID, userID) {
		return nil, ErrNotMember
	}
	b, err := scanBooking(s.pool.QueryRow(ctx, `
		UPDATE bookings SET status='cancelled', updated_at=now()
		WHERE id = (SELECT id FROM bookings WHERE match_id=$1 AND status IN ('proposed','confirmed')
		            ORDER BY created_at DESC LIMIT 1)
		RETURNING `+bookingCols, matchID))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNoBooking
	}
	return b, err
}
