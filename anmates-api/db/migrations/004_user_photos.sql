-- 004_user_photos.sql — gallery photos for the onboarding "Show bản thân" step (Screen 10).
-- The main avatar still lives in users.avatar_url (fast access for feeds/discovery);
-- this table holds the additional gallery photos (with optional captions + order).
-- Additive + idempotent so re-runs and existing rows are safe.

CREATE TABLE IF NOT EXISTS user_photos (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  url        text NOT NULL,
  caption    text,
  position   smallint NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_photos_user ON user_photos(user_id, position);
