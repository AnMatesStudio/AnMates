-- 007_user_locations.sql — last-known coarse location per user.
-- Pushed by the app (PUT /api/v1/me/location); used to compute the meetup midpoint.
-- One row per user (upsert). Coarse precision only — never exposed to other users
-- (we only ever return derived venues / midpoints, never raw coordinates).

CREATE TABLE user_locations (
  user_id     uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  lat         double precision NOT NULL,
  lng         double precision NOT NULL,
  district    text,
  updated_at  timestamptz NOT NULL DEFAULT now()
);
