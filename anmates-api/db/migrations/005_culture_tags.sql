-- 005_culture_tags.sql — add culture_tags column for Screen 10 (Thích Vibe Nào).
-- Additive + idempotent so re-runs are safe.

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS culture_tags text[] NOT NULL DEFAULT '{}';
