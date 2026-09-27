-- 020_trust_safety.sql — launch blockers: consent + age at sign-up, email verification, suspension,
-- admins, and a resolvable report queue with automatic suspension after 3 distinct reporters in 30 days.

ALTER TABLE users ADD COLUMN IF NOT EXISTS terms_accepted_at timestamptz;
ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verified_at timestamptz;
ALTER TABLE users ADD COLUMN IF NOT EXISTS suspended_at      timestamptz;
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_admin          boolean NOT NULL DEFAULT false;

-- Accounts that existed before verification was required keep working (grandfathered).
UPDATE users SET email_verified_at = COALESCE(email_verified_at, created_at)
  WHERE email IS NOT NULL AND email_verified_at IS NULL AND terms_accepted_at IS NULL;

-- The seeded operator account (013_seed_admin.sql) is the first admin.
UPDATE users SET is_admin = TRUE WHERE email = 'admin';

ALTER TABLE user_reports ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'open';
ALTER TABLE user_reports DROP CONSTRAINT IF EXISTS user_reports_status_check;
ALTER TABLE user_reports ADD CONSTRAINT user_reports_status_check CHECK (status IN ('open','dismissed','actioned'));
ALTER TABLE user_reports ADD COLUMN IF NOT EXISTS resolved_at timestamptz;
ALTER TABLE user_reports ADD COLUMN IF NOT EXISTS resolved_by uuid REFERENCES users(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_user_reports_status_created ON user_reports(status, created_at DESC);

-- Three different people reporting the same account within 30 days suspends it until an admin reviews.
CREATE OR REPLACE FUNCTION anm_auto_suspend() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF (SELECT count(DISTINCT reporter_id) FROM user_reports
       WHERE reported_id = NEW.reported_id AND created_at > now() - interval '30 days') >= 3 THEN
    UPDATE users SET suspended_at = now() WHERE id = NEW.reported_id AND suspended_at IS NULL;
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_auto_suspend ON user_reports;
CREATE TRIGGER trg_auto_suspend AFTER INSERT ON user_reports FOR EACH ROW EXECUTE FUNCTION anm_auto_suspend();
