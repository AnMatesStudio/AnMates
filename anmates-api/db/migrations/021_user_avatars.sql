-- 021_user_avatars.sql — profile photos stored IN the database, like venue photos (014).
--
-- Why not Firebase Storage (where onboarding v1 put photos): the project's bucket
-- answers 412 "A required service account is missing necessary permissions", so
-- every upload fails — and a photo is only as durable as the host behind it.
-- Keeping the bytes next to the user row makes it live and die with the account.
--
-- One row per user: the photo they cropped in the app, re-encoded server-side to
-- JPEG (metadata stripped). users.avatar_url then points at the serving route,
-- versioned by sha256 so a new photo is a new URL:
--   /api/v1/users/<id>/avatar?v=<sha256[:12]>
-- A bundled illustration is chosen instead with avatar_url = 'asset:<path>' and
-- needs no row here; a stale row is kept so the user can switch back later.

CREATE TABLE IF NOT EXISTS user_avatars (
  user_id     uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  data_base64 text NOT NULL,
  mime_type   text NOT NULL CHECK (mime_type = 'image/jpeg'),
  byte_size   int  NOT NULL CHECK (byte_size > 0),
  -- Hex sha256 of the decoded bytes: the ETag and the URL's version.
  sha256      text NOT NULL,
  updated_at  timestamptz NOT NULL DEFAULT now()
);
