-- 012_email_otp.sql — passwordless email-OTP login (alternative to Firebase phone
-- OTP, no reCAPTCHA). The backend mints a 6-digit code, e-mails it, and on a
-- correct+unexpired code upserts a user by email and issues the app JWT pair.

CREATE TABLE email_otps (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email       text NOT NULL,
  code_hash   text NOT NULL,
  expires_at  timestamptz NOT NULL,
  consumed_at timestamptz,
  attempts    int NOT NULL DEFAULT 0,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- Verify/cooldown both look up the newest row for an email.
CREATE INDEX idx_email_otps_email_created ON email_otps(email, created_at DESC);
-- Lets a periodic job (or a future cron) prune expired codes cheaply.
CREATE INDEX idx_email_otps_expires ON email_otps(expires_at);
