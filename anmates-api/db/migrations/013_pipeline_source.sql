-- 013_pipeline_source.sql — let the Data_Pipeline ETL own rows in `restaurants`.
--
-- RECONSTRUCTED 2026-09-03: this file was applied to the live DB on 2026-08-30
-- (see schema_migrations) but was never committed — it existed only untracked
-- on disk and was gone by the time this session started. A fresh clone /
-- fresh database would hit a CHECK violation the moment serving/sync_anmates.py
-- (Data_Pipeline repo) tried to upsert a 'pipeline' row, so this recreates it
-- from the live constraint definitions (`pg_get_constraintdef`) rather than
-- leave prod and git silently diverged. Safe to re-run: DROP/ADD CONSTRAINT
-- IF EXISTS and CREATE INDEX IF NOT EXISTS are both idempotent, and this exact
-- state is already live, so applying it again is a no-op.
--
-- 'pipeline' rows are owned by serving/sync_anmates.py in the sibling
-- Data_Pipeline repo, keyed by (source, source_ref) where source_ref is the
-- pipeline's own foodrec.restaurants.id (as text). The partial unique index
-- is what the sync's ON CONFLICT (source, source_ref) upsert relies on.

ALTER TABLE restaurants DROP CONSTRAINT IF EXISTS restaurants_source_check;
ALTER TABLE restaurants ADD CONSTRAINT restaurants_source_check
  CHECK (source IN ('seed', 'goong', 'osm', 'pipeline'));

CREATE UNIQUE INDEX IF NOT EXISTS idx_restaurants_source_ref
  ON restaurants(source, source_ref) WHERE source_ref IS NOT NULL;
