-- 015_sync_ledger.sql — per-batch and per-venue bookkeeping for AnMates-Data-Bridge.
--
-- Referenced by name in AnMates-Data-Bridge/docs/RUNBOOK.md and README.md as "stays in
-- this repo, applied via //go:embed" — but the file itself was never actually written.
-- bridge/app/db.py has queried sync_runs and sync_venue_state since the bridge was built;
-- every batch there was failing before it could open (INSERT INTO sync_runs -- relation
-- does not exist). Written from db.py's exact SQL, not from the docs' prose description.

-- One row per sync_anmates.py run. Opened and committed before a single venue is queued,
-- so a run that dies mid-batch still leaves a row explaining what it was doing.
CREATE TABLE sync_runs (
  batch_id     uuid PRIMARY KEY,
  started_at   timestamptz NOT NULL DEFAULT now(),
  finished_at  timestamptz,
  source_host  text NOT NULL,
  relay_host   text NOT NULL,
  mode         text NOT NULL,
  read_count   int NOT NULL DEFAULT 0,
  schema_ver   int NOT NULL,
  -- Bumped once per message actually enqueued (main.py:_bump_queued) -- distinct from
  -- upserted/photos, which only move once the WRITER drains that message. A batch stuck
  -- mid-queue shows queued > upserted+photos; that gap is the queue depth for this batch.
  queued       int NOT NULL DEFAULT 0,
  upserted     int NOT NULL DEFAULT 0,
  photos       int NOT NULL DEFAULT 0,
  skipped      int NOT NULL DEFAULT 0,
  -- A message that hit MAX_DELIVER and landed in BRIDGE_DLQ (writer.py:_bump_dlq).
  dlq          int NOT NULL DEFAULT 0,
  ok           boolean,
  error        text
);

-- One row per pipeline venue (source_ref), upserted on every batch that mentions it.
-- attempts/first_seen_at track a venue across many runs; last_change_at only moves when
-- outcome or reason actually changes, so "how long has this been stuck" stays meaningful
-- instead of resetting on every scheduled sync (see db.py's CASE in the state upsert).
CREATE TABLE sync_venue_state (
  source_ref      text PRIMARY KEY,
  label           text NOT NULL,
  outcome         text NOT NULL CHECK (outcome IN ('synced', 'skipped', 'failed')),
  reason          text,
  restaurant_id   uuid REFERENCES restaurants(id),
  deliveries      int NOT NULL DEFAULT 0,
  attempts        int NOT NULL DEFAULT 1,
  first_seen_at   timestamptz NOT NULL DEFAULT now(),
  last_seen_at    timestamptz NOT NULL DEFAULT now(),
  last_change_at  timestamptz NOT NULL DEFAULT now(),
  last_batch_id   uuid REFERENCES sync_runs(batch_id)
);

-- RUNBOOK Part E's daily query: "quán nào chưa vào được?" filters on this every time.
CREATE INDEX idx_sync_venue_state_outcome ON sync_venue_state(outcome)
  WHERE outcome <> 'synced';
