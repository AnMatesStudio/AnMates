-- 003_onboarding.sql — post-OTP onboarding profile + food/vibe preferences.
-- Adds columns to users for Screen 08 (Thông Tin Cá Nhân) + Screen 09 (Gú Ẩm Thực).
-- All additive + idempotent (IF NOT EXISTS) so re-runs and existing rows are safe.

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS nickname          text,
  ADD COLUMN IF NOT EXISTS birth_date        date,
  ADD COLUMN IF NOT EXISTS personality_score smallint,
  ADD COLUMN IF NOT EXISTS food_tags         text[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS vibe_tags         text[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS onboarding_done   boolean NOT NULL DEFAULT false;
