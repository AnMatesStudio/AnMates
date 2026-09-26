-- 016_chat_bots_reads.sql — Messenger-style inbox: read receipts + demo chat bots.

-- 1) Read receipts. One row per (match, member): everything the partner sent at
--    or before last_read_at counts as seen. Drives the inbox unread count and
--    the "Đã xem" under your last message.
CREATE TABLE IF NOT EXISTS match_reads (
  match_id     uuid NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  last_read_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (match_id, user_id)
);

-- 2) Demo bots. Real users rows (so messages.sender_id and matches FKs hold)
--    flagged is_bot: they never enter anyone's swipe deck — a user reaches them
--    only through POST /api/v1/demo/bots — and they answer chat server-side.
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_bot boolean NOT NULL DEFAULT false;

INSERT INTO users (id, email, name, bio, food_tags, vibe_tags, onboarding_done, is_bot)
VALUES
  ('00000000-0000-0000-0000-0000000000b1', 'bot-lau@anmates.bot', 'Bot Minh Anh',
   'Bot demo — mê lẩu và ốc, hay rủ đi ăn khuya.', '{lau,oc}', '{Đi ăn khuya}', true, true),
  ('00000000-0000-0000-0000-0000000000b2', 'bot-nuong@anmates.bot', 'Bot Hoàng Nam',
   'Bot demo — fan BBQ Hàn, cuối tuần là đi nướng.', '{nuong,bia}', '{BBQ Hàn}', true, true),
  ('00000000-0000-0000-0000-0000000000b3', 'bot-cafe@anmates.bot', 'Bot Thu Trang',
   'Bot demo — cà phê sáng, tráng miệng chiều.', '{cafe,trang_mieng}', '{Cà phê}', true, true),
  ('00000000-0000-0000-0000-0000000000b4', 'bot-pho@anmates.bot', 'Bot Quốc Bảo',
   'Bot demo — phở, bún bò, món nước là chân ái.', '{pho,bun}', '{Món nước}', true, true)
ON CONFLICT (id) DO UPDATE SET is_bot = true;
