-- 013_seed_admin.sql — seed a fixed admin/admin account for the simplified
-- password login flow (replaces Firebase phone OTP as the app's entry auth).
-- Hash is bcrypt cost-10 of "admin"; onboarding_done=true skips onboarding.
INSERT INTO users (email, password_hash, name, onboarding_done)
VALUES (
  'admin',
  '$2a$10$hvsXI9SI.e6cCBfOM1xI2uMV5GbSeHmch/I.nUBlmhp4pqW2a/QjC',
  'Admin',
  true
)
ON CONFLICT (email) DO NOTHING;
