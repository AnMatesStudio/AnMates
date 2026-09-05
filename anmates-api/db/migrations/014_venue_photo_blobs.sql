-- 014_venue_photo_blobs.sql — store venue photos IN the database as encoded text
-- instead of pointing at an external host.
--
-- Why: restaurants.photos held bare URLs, all 117 of them on the data pipeline's
-- own ngrok tunnel (411e-42-118-190-221.ngrok-free.app). The tunnel died and every
-- venue photo died with it — a URL is only as durable as the host behind it, and
-- the pipeline's host is by nature ephemeral. Holding the bytes ourselves makes a
-- photo outlive whatever machine produced it.
--
-- data_base64 is the image encoded as text (base64, no `data:` prefix, no line
-- breaks). Postgres TOASTs it out of line automatically past ~2KB. Note that
-- base64 of an already-compressed JPEG/PNG does not compress further, so a row
-- costs ~1.33x the original file; `bytea` would avoid that overhead if this ever
-- needs to scale beyond the current catalogue.
--
-- restaurants.photos is intentionally left in place: it is now provenance (where
-- the image came from), not the serving path. The API serves bytes from here.

CREATE TABLE IF NOT EXISTS venue_photos (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id uuid NOT NULL REFERENCES restaurants(id) ON DELETE CASCADE,

  -- Display order within a venue's gallery; 0 is the hero/thumbnail.
  position      smallint NOT NULL DEFAULT 0,

  -- The image itself, base64-encoded.
  data_base64   text NOT NULL,
  mime_type     text NOT NULL CHECK (mime_type IN ('image/jpeg','image/png','image/webp','image/gif')),

  -- Decoded byte length, so callers can size a response without decoding, and
  -- so a corrupt/truncated row is detectable.
  byte_size     int NOT NULL CHECK (byte_size > 0),

  -- Hex sha256 of the DECODED bytes. Doubles as the ETag and as the dedup key:
  -- re-ingesting the same image for the same venue is a no-op.
  sha256        text NOT NULL,

  -- Where the bytes were fetched from. Kept for provenance/debugging only —
  -- it may already be dead, which is the whole reason this table exists.
  source_url    text,

  created_at    timestamptz NOT NULL DEFAULT now()
);

-- One image per slot, and the same image never stored twice for one venue.
CREATE UNIQUE INDEX IF NOT EXISTS idx_venue_photos_slot
  ON venue_photos(restaurant_id, position);
CREATE UNIQUE INDEX IF NOT EXISTS idx_venue_photos_dedup
  ON venue_photos(restaurant_id, sha256);

-- The serving path always reads a venue's gallery in order.
CREATE INDEX IF NOT EXISTS idx_venue_photos_gallery
  ON venue_photos(restaurant_id, position);
