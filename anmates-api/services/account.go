package services

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type AccountStatus struct {
	Email         *string `json:"email"`
	EmailVerified bool    `json:"email_verified"`
	Suspended     bool    `json:"suspended"`
	IsAdmin       bool    `json:"is_admin"`
	TermsAccepted bool    `json:"terms_accepted"`
}

type AdminReport struct {
	ID              uuid.UUID `json:"id"`
	ReporterID      uuid.UUID `json:"reporter_id"`
	ReporterName    string    `json:"reporter_name"`
	ReportedID      uuid.UUID `json:"reported_id"`
	ReportedName    string    `json:"reported_name"`
	ReportedSuspend bool      `json:"reported_suspended"`
	Reason          string    `json:"reason"`
	Note            string    `json:"note"`
	Status          string    `json:"status"`
	CreatedAt       time.Time `json:"created_at"`
}

// ErrBadAction is returned by ResolveReport for an unknown action.
var ErrBadAction = errors.New("bad action")

type AccountService struct{ pool *pgxpool.Pool }

func NewAccountService(pool *pgxpool.Pool) *AccountService { return &AccountService{pool: pool} }

// Status returns the account's email, verification, suspension and admin state.
func (s *AccountService) Status(ctx context.Context, userID uuid.UUID) (*AccountStatus, error) {
	var st AccountStatus
	err := s.pool.QueryRow(ctx, `
		SELECT email,
		       email IS NULL OR email_verified_at IS NOT NULL,
		       suspended_at IS NOT NULL,
		       is_admin,
		       terms_accepted_at IS NOT NULL
		FROM users WHERE id = $1
	`, userID).Scan(&st.Email, &st.EmailVerified, &st.Suspended, &st.IsAdmin, &st.TermsAccepted)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	return &st, nil
}

// Gate reports whether the user is suspended and whether they have an unverified email.
func (s *AccountService) Gate(ctx context.Context, userID uuid.UUID) (suspended bool, unverified bool, err error) {
	err = s.pool.QueryRow(ctx, `
		SELECT suspended_at IS NOT NULL,
		       email IS NOT NULL AND email_verified_at IS NULL
		FROM users WHERE id = $1
	`, userID).Scan(&suspended, &unverified)
	if errors.Is(err, pgx.ErrNoRows) {
		return false, false, ErrNotFound
	}
	if err != nil {
		return false, false, err
	}
	return suspended, unverified, nil
}

// IsAdmin reports whether the user is an admin; an unknown user is not.
func (s *AccountService) IsAdmin(ctx context.Context, userID uuid.UUID) (bool, error) {
	var isAdmin bool
	err := s.pool.QueryRow(ctx, `SELECT is_admin FROM users WHERE id = $1`, userID).Scan(&isAdmin)
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	return isAdmin, nil
}

// RecordSignup sets the user's birth date and marks the terms as accepted.
func (s *AccountService) RecordSignup(ctx context.Context, userID uuid.UUID, birthDate time.Time) error {
	_, err := s.pool.Exec(ctx, `
		UPDATE users SET birth_date = $2, terms_accepted_at = now() WHERE id = $1
	`, userID, birthDate)
	return err
}

// MarkEmailVerified stamps the user's email as verified if not already.
func (s *AccountService) MarkEmailVerified(ctx context.Context, userID uuid.UUID) error {
	_, err := s.pool.Exec(ctx, `
		UPDATE users SET email_verified_at = now() WHERE id = $1 AND email_verified_at IS NULL
	`, userID)
	return err
}

// ListReports returns up to 100 reports with the given status, newest first.
func (s *AccountService) ListReports(ctx context.Context, status string) ([]AdminReport, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT r.id, r.reporter_id, COALESCE(ru.name, ''), r.reported_id, COALESCE(tu.name, ''),
		       tu.suspended_at IS NOT NULL, r.reason, r.note, r.status, r.created_at
		FROM user_reports r
		JOIN users ru ON ru.id = r.reporter_id
		JOIN users tu ON tu.id = r.reported_id
		WHERE r.status = $1
		ORDER BY r.created_at DESC
		LIMIT 100
	`, status)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	reports := []AdminReport{}
	for rows.Next() {
		var rep AdminReport
		if err := rows.Scan(&rep.ID, &rep.ReporterID, &rep.ReporterName, &rep.ReportedID, &rep.ReportedName,
			&rep.ReportedSuspend, &rep.Reason, &rep.Note, &rep.Status, &rep.CreatedAt); err != nil {
			return nil, err
		}
		reports = append(reports, rep)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return reports, nil
}

// ResolveReport applies the admin's dismiss or suspend action to a report in one transaction.
func (s *AccountService) ResolveReport(ctx context.Context, reportID, adminID uuid.UUID, action string) error {
	status := ""
	switch action {
	case "dismiss":
		status = "dismissed"
	case "suspend":
		status = "actioned"
	default:
		return ErrBadAction
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	var reportedID uuid.UUID
	err = tx.QueryRow(ctx, `
		UPDATE user_reports SET status = $2, resolved_at = now(), resolved_by = $3
		WHERE id = $1 RETURNING reported_id
	`, reportID, status, adminID).Scan(&reportedID)
	if errors.Is(err, pgx.ErrNoRows) {
		return ErrNotFound
	}
	if err != nil {
		return err
	}

	if action == "suspend" {
		if _, err := tx.Exec(ctx, `
			UPDATE users SET suspended_at = COALESCE(suspended_at, now()) WHERE id = $1
		`, reportedID); err != nil {
			return err
		}
	}
	return tx.Commit(ctx)
}

// Unsuspend clears the user's suspension timestamp.
func (s *AccountService) Unsuspend(ctx context.Context, userID uuid.UUID) error {
	tag, err := s.pool.Exec(ctx, `UPDATE users SET suspended_at = NULL WHERE id = $1`, userID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}
