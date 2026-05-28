# AnMates API — Load Test

Simulates real mobile traffic against the Go API running inside Docker with the same
resource limits as a GCP Cloud Run 1 vCPU / 1 GB instance.

## Prerequisites

| Tool | Minimum version | Check |
|------|----------------|-------|
| Docker Desktop | 4.x | `docker --version` |
| Docker Compose plugin | v2 | `docker compose version` |
| PowerShell | 5.1 (Windows) / pwsh 7 (Mac/Linux) | `$PSVersionTable` |

No Go, Node, or k6 installation required — everything runs inside Docker.

---

## Quick start

```sh
npm run load-test
```

Or directly from a bash/WSL terminal:

```bash
bash load-test/run.sh
```

That's it. The script will:
1. Build the API image from `../anmates-api/`
2. Start Postgres (256 MB limit)
3. Start the API (1 vCPU / 1 GB limit — mirrors GCP)
4. Run k6 with 100 pre-created users, ramping to 500 concurrent VUs
5. Tear down all containers
6. Print a colour-coded report with SLO pass/fail

---

## Options

```sh
# Default run (500 VUs, 100 users, ~4 min)
npm run load-test

# Quick sanity check (50 VUs, 20 users)
npm run load-test:smoke

# Wipe previous results then run
npm run load-test:clean
```

Or with the bash script directly:

```bash
bash load-test/run.sh              # default
bash load-test/run.sh -v 200 -u 50 -c   # 200 VUs, 50 users, clean first
```

| Flag | Default | Description |
|------|---------|-------------|
| `-v <n>` | 500 | Peak concurrent virtual users |
| `-u <n>` | 100 | Pre-created user accounts shared across VUs |
| `-c` | off | Wipe `results/raw.json` before starting |
| `-h` | — | Show help |

---

## What the test does

### Traffic mix (realistic mobile usage)

| Weight | Endpoint | Notes |
|--------|----------|-------|
| 5% | `GET /health` | Unauthenticated baseline |
| 20% | `GET /api/v1/profile` | Most common on app open |
| 20% | `GET /api/v1/wishlist` | Read-heavy screen |
| 20% | `POST /api/v1/wishlist` | Write traffic (stresses DB pool) |
| 15% | `GET /api/v1/matches` | Feed screen |
| 12% | `GET /api/v1/conversations` | Chat list |
| 8% | `POST /api/v1/auth/dev-login` | Token refresh simulation |

Each VU adds 0.5–1.5 s of think time between requests (realistic mobile pacing).

### Ramp stages

```
VUs  500 ┤                          ████
         │                       ███    ███
    300 ┤              ███████████
         │         ████
     50 ┤    ██████
         │████
      0 ┤─────────────────────────────────▶ time
         0  30s  90s  150s 180s  210s
```

### SLOs checked automatically

| Metric | Threshold | Fails test if |
|--------|-----------|---------------|
| p95 latency | < 500 ms | exceeded |
| p99 latency | < 1000 ms | exceeded |
| Error rate | < 1% | exceeded |
| Per-endpoint p95 | < 400–500 ms | shown in output |

---

## Output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ANMATES API LOAD TEST REPORT  —  2026-05-28 11:04
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  SETUP
  User pool  : 100 tokens
  Peak VUs   : 498
  Test time  : 211s  (wall: 280s)

  THROUGHPUT
  Total reqs : 48903
  Avg req/s  : 231.9
  Data sent  : 20.22 MB
  Data recv  : 10.13 MB

  LATENCY (ms)
  p50  :  0.44
  p75  :  0.55
  p90  :  0.73
  p95  :  1.61   — SLO <500ms  [PASS]
  p99  :  4.65   — SLO <1000ms [PASS]
  max  :  47.29

  ERRORS
  2xx  :  48903
  4xx  :  0
  5xx  :  0
  Rate :  0%     — SLO <1%    [PASS]

  RESULT: ALL SLOs PASSED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Raw data: load-test\results\raw.json
```

Raw JSON telemetry is saved to `results/raw.json` for deeper analysis (k6 JSONL format —
one metric event per line).

---

## Resource limits (mirrors production)

| Service | CPU | Memory |
|---------|-----|--------|
| Postgres | uncapped | 256 MB |
| API | 1.0 vCPU (hard cap) | 1024 MB |
| k6 | uncapped | 256 MB |

The API `GOMAXPROCS=1` and `GOMEMLIMIT=900MiB` env vars match the Cloud Run deployment.

---

## Interpreting results

| p95 latency | Interpretation |
|-------------|----------------|
| < 50 ms | Excellent — well within budget |
| 50–200 ms | Good — normal for DB-backed endpoints |
| 200–500 ms | Acceptable — review slow endpoints |
| > 500 ms | **SLO breach** — investigate before deploying |

| Error rate | Interpretation |
|-----------|----------------|
| 0% | Ideal |
| < 0.1% | Acceptable (transient noise) |
| 0.1–1% | Investigate — likely pool contention or timeout |
| > 1% | **SLO breach** — do not ship |

### Common failure modes

**High p99 / spike on max:** usually means Postgres connection pool is queueing.
Increase `PG_MAX_CONNS` (rule of thumb: 4 × vCPU count) or reduce VU count.

**5xx errors:** API crashed or OOM-killed. Check `docker stats` during the run.

**4xx errors:** Almost always a test-script bug (wrong payload, expired token).
Never treat 4xx as a capacity signal.

**k6 exits immediately:** API failed health check. Check `docker compose logs api`.

---

## Running directly (without npm)

```bash
# From WSL or any bash terminal
cd load-test
bash run.sh

# Or with docker compose directly (no report)
docker compose up --build --abort-on-container-exit
docker compose down
```

---

## Files

```
load-test/
├── README.md            <- this file
├── run.sh               <- one-command bash runner + report printer
├── docker-compose.yml   <- db + api + k6 stack with resource limits
├── k6-script.js         <- k6 load test scenarios + thresholds
└── results/
    └── raw.json         <- k6 JSONL output (git-ignored)
```
