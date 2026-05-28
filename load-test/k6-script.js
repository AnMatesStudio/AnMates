import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Counter, Rate } from 'k6/metrics';

// ─── Custom metrics ───────────────────────────────────────────────
const profileLatency       = new Trend('profile_latency',       true);
const wishlistLatency      = new Trend('wishlist_latency',      true);
const matchesLatency       = new Trend('matches_latency',       true);
const conversationsLatency = new Trend('conversations_latency', true);
const authLatency          = new Trend('auth_latency',          true);
const errorCount           = new Counter('errors');
const errorRate            = new Rate('error_rate');

// ─── Load profile — overridable via env ──────────────────────────
// CI sets PEAK_VUS=50 and shorter stages; local uses defaults (500 VUs).
const PEAK_VUS = parseInt(__ENV.PEAK_VUS || '500', 10);
const CI_MODE  = __ENV.CI_MODE === 'true';

const stages = CI_MODE
  ? [
      { duration: '20s', target: PEAK_VUS },  // ramp
      { duration: '60s', target: PEAK_VUS },  // sustain
      { duration: '10s', target: 0         },  // cooldown
    ]
  : [
      { duration: '30s', target: 50        },  // warm-up
      { duration: '60s', target: 300       },  // ramp
      { duration: '60s', target: 300       },  // sustain
      { duration: '30s', target: PEAK_VUS  },  // peak spike
      { duration: '30s', target: 0         },  // cooldown
    ];

export const options = {
  scenarios: {
    load: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages,
      gracefulRampDown: '15s',
    },
  },
  thresholds: {
    http_req_duration:       ['p(95)<500', 'p(99)<1000'],
    http_req_failed:         ['rate<0.01'],
    error_rate:              ['rate<0.01'],
    profile_latency:         ['p(95)<400'],
    wishlist_latency:        ['p(95)<400'],
    matches_latency:         ['p(95)<500'],
    conversations_latency:   ['p(95)<500'],
  },
};

const BASE_URL   = __ENV.BASE_URL   || 'http://localhost:8080';
const DEV_SECRET = __ENV.DEV_SECRET || 'loadtest-secret-2026';
const USER_POOL  = parseInt(__ENV.USER_POOL || '500', 10);

// TARGET_HANDLERS: comma-separated handler names to stress-test.
// 'all' (default) runs every scenario with original weights.
// Example: 'wishlist,matching' runs only those endpoints; weights renormalised.
// Recognised names: health, user, wishlist, matching, auth
const _rawTargets = (__ENV.TARGET_HANDLERS || 'all').toLowerCase();
const ALL_TARGETS = new Set(['health', 'user', 'wishlist', 'matching', 'auth']);
const targets = _rawTargets === 'all'
  ? ALL_TARGETS
  : new Set(_rawTargets.split(',').map(s => s.trim()).filter(s => ALL_TARGETS.has(s)));

// ─── Scenario table ───────────────────────────────────────────────
// Each entry: { name, weight, run(h) }
// Weights are relative; they are renormalised after target filtering.
const SCENARIOS = [
  { name: 'health',   weight: 5,  run: runHealth   },
  { name: 'user',     weight: 20, run: runProfile  },
  { name: 'wishlist', weight: 40, run: runWishlist  },
  { name: 'matching', weight: 27, run: runMatching  },
  { name: 'auth',     weight: 8,  run: runAuth      },
];

// Filter to targets then compute cumulative weight bands
const active = SCENARIOS.filter(s => targets.has(s.name));
const totalWeight = active.reduce((sum, s) => sum + s.weight, 0);
let cum = 0;
const bands = active.map(s => {
  cum += s.weight / totalWeight;
  return { threshold: cum, run: s.run };
});

// ─── setup(): build user pool ─────────────────────────────────────
export function setup() {
  let ready = false;
  for (let i = 0; i < 20; i++) {
    const r = http.get(`${BASE_URL}/health`, { timeout: '3s' });
    if (r.status === 200) { ready = true; break; }
    sleep(3);
  }
  if (!ready) throw new Error('API did not become healthy within 60 s');

  if (CI_MODE) {
    console.log(`CI mode: targets=[${[...targets].join(',')}] peak=${PEAK_VUS} VUs`);
  }

  const tokens = [];
  for (let i = 0; i < USER_POOL; i++) {
    const email   = `loadtest-${i}@anmates.dev`;
    const payload = JSON.stringify({ email, secret: DEV_SECRET });
    const headers = { 'Content-Type': 'application/json' };
    const r = http.post(`${BASE_URL}/api/v1/auth/dev-login`, payload, { headers, timeout: '5s' });
    if (r.status !== 200) {
      console.warn(`User ${i}: dev-login failed (${r.status})`);
      continue;
    }
    const body = JSON.parse(r.body);
    const tok  = body.data && body.data.access_token;
    if (tok) tokens.push(tok);
  }

  if (tokens.length === 0) throw new Error('setup(): zero tokens acquired — abort');
  console.log(`setup(): ${tokens.length}/${USER_POOL} tokens acquired`);
  return { tokens };
}

// ─── helpers ──────────────────────────────────────────────────────
function authHeaders(token) {
  return { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' };
}
function pick(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}
function record(res, trend, label, okStatuses) {
  const ok = okStatuses
    ? okStatuses.includes(res.status)
    : res.status >= 200 && res.status < 300;
  if (!ok) { errorCount.add(1); errorRate.add(1); console.warn(`${label}: ${res.status}`); }
  else      { errorRate.add(0); }
  if (trend) trend.add(res.timings.duration);
  check(res, { [`${label} ok`]: () => ok });
  return ok;
}

// ─── Scenario implementations ─────────────────────────────────────
function runHealth() {
  const r = http.get(`${BASE_URL}/health`, { timeout: '3s' });
  record(r, null, 'GET /health');
}

function runProfile(h) {
  const r = http.get(`${BASE_URL}/api/v1/profile`, { headers: h, timeout: '5s' });
  record(r, profileLatency, 'GET /profile');
}

function runWishlist(h) {
  const roll = Math.random();
  if (roll < 0.5) {
    const r = http.get(`${BASE_URL}/api/v1/wishlist`, { headers: h, timeout: '5s' });
    record(r, wishlistLatency, 'GET /wishlist');
  } else {
    const foods = [
      'Lẩu bò', 'Bánh mì', 'Phở gà', 'Bún chả', 'Cơm tấm', 'Bánh xèo',
      'Bánh cuốn', 'Bún bò Huế', 'Cháo lòng', 'Hủ tiếu', 'Mì Quảng',
      'Bánh canh', 'Cơm hến', 'Xôi gà', 'Bún thịt nướng', 'Chả giò',
      'Gỏi cuốn', 'Bánh tráng trộn', 'Cơm chiên dương châu', 'Lẩu hải sản',
    ];
    const cats = ['bun', 'pho', 'com', 'lau', 'bbq', 'cafe', 'trang_mieng', 'other'];
    const body = JSON.stringify({ food_name: pick(foods), food_category: pick(cats) });
    const r = http.post(`${BASE_URL}/api/v1/wishlist`, body, {
      headers: h,
      timeout: '5s',
      responseCallback: http.expectedStatuses(200, 201, 409),
    });
    record(r, wishlistLatency, 'POST /wishlist', [200, 201, 409]);
  }
}

function runMatching(h) {
  const roll = Math.random();
  if (roll < 0.55) {
    const r = http.get(`${BASE_URL}/api/v1/matches`, { headers: h, timeout: '5s' });
    record(r, matchesLatency, 'GET /matches');
  } else {
    const r = http.get(`${BASE_URL}/api/v1/conversations`, { headers: h, timeout: '5s' });
    record(r, conversationsLatency, 'GET /conversations');
  }
}

function runAuth() {
  const i       = Math.floor(Math.random() * USER_POOL);
  const payload = JSON.stringify({ email: `loadtest-${i}@anmates.dev`, secret: DEV_SECRET });
  const r = http.post(`${BASE_URL}/api/v1/auth/dev-login`, payload, {
    headers: { 'Content-Type': 'application/json' }, timeout: '5s',
  });
  record(r, authLatency, 'POST /auth/dev-login');
}

// ─── default VU ──────────────────────────────────────────────────
export default function ({ tokens }) {
  if (!tokens || tokens.length === 0) return;
  const token = pick(tokens);
  const h     = authHeaders(token);

  // Weighted random pick from active scenario bands
  const roll = Math.random();
  for (const band of bands) {
    if (roll < band.threshold) {
      band.run(h);
      break;
    }
  }

  sleep(0.5 + Math.random()); // 0.5–1.5 s think time
}

export function teardown(data) {
  console.log(`teardown(): ${data.tokens.length} tokens used`);
}
