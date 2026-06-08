-- 009_concierge_too_far.sql — allow the new 'skipped_too_far' run status.
-- The concierge now skips suggesting (and posts a friendly notice) when the two
-- matched users are farther apart than AI_MAX_SEPARATION_M. Record that outcome
-- distinctly from the generic 'skipped_preconds' (no location / no picks).
-- IF EXISTS keeps the migration idempotent on re-run.
ALTER TABLE ai_concierge_runs DROP CONSTRAINT IF EXISTS ai_concierge_runs_status_check;
ALTER TABLE ai_concierge_runs ADD CONSTRAINT ai_concierge_runs_status_check
  CHECK (status IN ('fired','skipped_preconds','skipped_too_far','error'));
