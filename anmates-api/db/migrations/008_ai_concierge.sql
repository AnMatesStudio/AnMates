-- 008_ai_concierge.sql — AI Concierge trigger ledger + idempotency, AI system user,
-- and the new chat message type. See docs/specs/ai-concierge-chat-spec.md.

-- 1) Reserved AI system user. Messages authored by the concierge use this id so the
--    messages.sender_id FK is satisfied. Fixed UUID — referenced by AI_USER_ID in config.
--    Satisfies users_identity_check (email present) and name NOT NULL.
INSERT INTO users (id, email, name)
VALUES ('00000000-0000-0000-0000-0000000000a1', 'ai@anmates.system', 'Trợ lý ĂnMates')
ON CONFLICT (id) DO NOTHING;

-- 2) Allow the new chat message type. The 001 inline CHECK is auto-named
--    messages_msg_type_check; replace it to include 'ai_venue_card'.
--    IF EXISTS keeps the migration idempotent on re-run.
ALTER TABLE messages DROP CONSTRAINT IF EXISTS messages_msg_type_check;
ALTER TABLE messages ADD CONSTRAINT messages_msg_type_check
  CHECK (msg_type IN ('text','image','system','ai_venue_card'));

-- 3) Concierge run ledger: idempotency guard + cost/analytics record.
CREATE TABLE ai_concierge_runs (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id     uuid NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  trigger      text NOT NULL,                       -- 'vibe_70'
  status       text NOT NULL                        -- 'fired' | 'skipped_preconds' | 'error'
    CHECK (status IN ('fired','skipped_preconds','error')),
  message_id   uuid REFERENCES messages(id) ON DELETE SET NULL,
  model        text,
  cost_tokens  int,
  created_at   timestamptz NOT NULL DEFAULT now()
);

-- At most one successful fire per match (the trigger is a once-per-milestone event).
CREATE UNIQUE INDEX ai_runs_one_fired_per_match
  ON ai_concierge_runs(match_id) WHERE status = 'fired';

CREATE INDEX idx_ai_runs_match ON ai_concierge_runs(match_id, created_at DESC);
