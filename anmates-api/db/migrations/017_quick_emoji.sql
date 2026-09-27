-- 017_quick_emoji.sql — the chat's quick-reaction emoji (Messenger's "like"),
-- one per conversation and shared by both members.
ALTER TABLE matches ADD COLUMN IF NOT EXISTS quick_emoji text NOT NULL DEFAULT '👍';

-- A change is also a transcript line ("X đã đổi biểu tượng cảm xúc thành 🍜"),
-- so it reaches the partner's socket like any message. content = the new emoji.
ALTER TABLE messages DROP CONSTRAINT IF EXISTS messages_msg_type_check;
ALTER TABLE messages ADD CONSTRAINT messages_msg_type_check
  CHECK (msg_type IN ('text','image','system','ai_venue_card','quick_emoji'));
