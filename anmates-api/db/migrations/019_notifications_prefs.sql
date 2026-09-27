-- 019_notifications_prefs.sql — price-tier match preference, and in-app notifications fed by triggers
-- (new match, message, booking proposed/confirmed/cancelled, meal rating) so no Go code path can forget one.

ALTER TABLE users ADD COLUMN IF NOT EXISTS price_tier smallint CHECK (price_tier BETWEEN 0 AND 3);

-- notifications: one row per event for one recipient; read_at NULL = unread.
CREATE TABLE IF NOT EXISTS notifications (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  kind       text NOT NULL CHECK (kind IN
               ('match','message','booking_proposed','booking_confirmed','booking_cancelled','rating')),
  match_id   uuid REFERENCES matches(id) ON DELETE CASCADE,
  actor_id   uuid REFERENCES users(id) ON DELETE CASCADE,
  read_at    timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_notifications_user_created ON notifications(user_id, created_at DESC);

-- The other member of a match.
CREATE OR REPLACE FUNCTION anm_other_member(p_match uuid, p_user uuid) RETURNS uuid
LANGUAGE sql STABLE AS $$
  SELECT CASE WHEN user_a_id = p_user THEN user_b_id ELSE user_a_id END FROM matches WHERE id = p_match
$$;

CREATE OR REPLACE FUNCTION anm_notify_match() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO notifications (user_id, kind, match_id, actor_id) VALUES
    (NEW.user_a_id, 'match', NEW.id, NEW.user_b_id),
    (NEW.user_b_id, 'match', NEW.id, NEW.user_a_id);
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_notify_match ON matches;
CREATE TRIGGER trg_notify_match AFTER INSERT ON matches FOR EACH ROW EXECUTE FUNCTION anm_notify_match();

-- Messages: at most one UNREAD message notification per match per recipient (no spam per line).
CREATE OR REPLACE FUNCTION anm_notify_message() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE rcpt uuid;
BEGIN
  IF NEW.msg_type NOT IN ('text','image') THEN RETURN NEW; END IF;
  rcpt := anm_other_member(NEW.match_id, NEW.sender_id);
  IF rcpt IS NULL THEN RETURN NEW; END IF;
  IF NOT EXISTS (SELECT 1 FROM notifications
                 WHERE user_id = rcpt AND match_id = NEW.match_id AND kind = 'message' AND read_at IS NULL) THEN
    INSERT INTO notifications (user_id, kind, match_id, actor_id) VALUES (rcpt, 'message', NEW.match_id, NEW.sender_id);
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_notify_message ON messages;
CREATE TRIGGER trg_notify_message AFTER INSERT ON messages FOR EACH ROW EXECUTE FUNCTION anm_notify_message();

CREATE OR REPLACE FUNCTION anm_notify_booking() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE other uuid;
BEGIN
  other := anm_other_member(NEW.match_id, NEW.proposed_by);
  IF TG_OP = 'INSERT' THEN
    INSERT INTO notifications (user_id, kind, match_id, actor_id)
      VALUES (other, 'booking_proposed', NEW.match_id, NEW.proposed_by);
  ELSIF NEW.status = 'confirmed' AND OLD.status IS DISTINCT FROM 'confirmed' THEN
    INSERT INTO notifications (user_id, kind, match_id, actor_id)
      VALUES (NEW.proposed_by, 'booking_confirmed', NEW.match_id, other);
  ELSIF NEW.status = 'cancelled' AND OLD.status IS DISTINCT FROM 'cancelled' THEN
    INSERT INTO notifications (user_id, kind, match_id, actor_id) VALUES
      (NEW.proposed_by, 'booking_cancelled', NEW.match_id, NULL),
      (other, 'booking_cancelled', NEW.match_id, NULL);
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_notify_booking ON bookings;
CREATE TRIGGER trg_notify_booking AFTER INSERT OR UPDATE OF status ON bookings
  FOR EACH ROW EXECUTE FUNCTION anm_notify_booking();

-- A rating tells the partner that one arrived (the stars stay private until both rate).
CREATE OR REPLACE FUNCTION anm_notify_rating() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO notifications (user_id, kind, match_id, actor_id)
    VALUES (anm_other_member(NEW.match_id, NEW.rater_id), 'rating', NEW.match_id, NEW.rater_id);
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_notify_rating ON meal_ratings;
CREATE TRIGGER trg_notify_rating AFTER INSERT ON meal_ratings FOR EACH ROW EXECUTE FUNCTION anm_notify_rating();
