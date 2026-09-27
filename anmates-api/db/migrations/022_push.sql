-- 022_push.sql — self-hosted delivery of notifications: Web Push subscriptions (RFC 8030/8291, our own VAPID keys),
-- a claim column so exactly one API replica sends each push, and pg_notify so every replica can relay new
-- notifications to its own WebSocket clients in real time.

CREATE TABLE IF NOT EXISTS push_subscriptions (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  endpoint     text NOT NULL UNIQUE,
  p256dh       text NOT NULL,
  auth         text NOT NULL,
  user_agent   text NOT NULL DEFAULT '',
  created_at   timestamptz NOT NULL DEFAULT now(),
  last_used_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_user ON push_subscriptions(user_id);

-- Set by the replica that won the right to send this notification's Web Push.
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS pushed_at timestamptz;

CREATE OR REPLACE FUNCTION anm_notification_created() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  PERFORM pg_notify('anm_notification', NEW.id::text);
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_notification_created ON notifications;
CREATE TRIGGER trg_notification_created AFTER INSERT ON notifications
  FOR EACH ROW EXECUTE FUNCTION anm_notification_created();
