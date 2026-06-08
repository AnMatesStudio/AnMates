-- 011_bookings.sql — First Date bookings for a match. One member proposes a venue
-- + time; the other confirms. At most one active (proposed|confirmed) booking per
-- match — re-proposing cancels the previous one (see services/booking.go).

CREATE TABLE bookings (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id           uuid NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  proposed_by        uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  restaurant_name    text NOT NULL,
  restaurant_address text NOT NULL DEFAULT '',
  lat                double precision,
  lng                double precision,
  scheduled_at       timestamptz NOT NULL,
  status             text NOT NULL DEFAULT 'proposed'
                       CHECK (status IN ('proposed','confirmed','cancelled','completed')),
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now()
);

-- Enforce a single live booking per match (cancelled/completed don't count).
CREATE UNIQUE INDEX uq_bookings_active ON bookings(match_id)
  WHERE status IN ('proposed','confirmed');
CREATE INDEX idx_bookings_match ON bookings(match_id, created_at DESC);
