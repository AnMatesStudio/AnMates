-- 010_swipes.sql — per-user swipe decisions enabling mutual-like matching.
-- A match is now created only when BOTH users have liked each other (see
-- services/matching.go Swipe). 'liked = false' records a pass so the candidate
-- is not shown again.

CREATE TABLE swipes (
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  target_id  uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  liked      boolean NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, target_id),
  CHECK (user_id <> target_id)
);

-- Reciprocity lookup: "has target liked me?"
CREATE INDEX idx_swipes_target_liked ON swipes(target_id, liked);
-- Undo (delete latest) + dedup in candidate listing.
CREATE INDEX idx_swipes_user_created ON swipes(user_id, created_at DESC);
