-- 023_meal_reliability.sql — anti no-show: reminders 24 h / 2 h before a confirmed meal (each sent once, safe across
-- API replicas), the day-of status ("on my way", "running late", "arrived"), and the notification kinds they need.

ALTER TABLE bookings ADD COLUMN IF NOT EXISTS reminded_24h_at timestamptz;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS reminded_2h_at  timestamptz;

-- Latest day-of status per member of a booking.
CREATE TABLE IF NOT EXISTS meal_status (
  booking_id uuid NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status     text NOT NULL CHECK (status IN ('on_my_way','running_late_10','running_late_20','arrived')),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (booking_id, user_id)
);

ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_kind_check;
ALTER TABLE notifications ADD CONSTRAINT notifications_kind_check CHECK (kind IN (
  'match','message','booking_proposed','booking_confirmed','booking_cancelled','rating',
  'booking_reminder_24h','booking_reminder_2h',
  'on_my_way','running_late_10','running_late_20','arrived'));
