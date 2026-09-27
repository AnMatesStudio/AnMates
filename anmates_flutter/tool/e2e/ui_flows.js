// Real-app UI e2e (docs/e2e-test-cases.md UI-05..UI-09): Me stats + blocked list/unblock,
// Bill → Rate with the partner's rating, Report and Unmatch from the chat menu. Every UI action
// is then checked against the API or DB — the screen alone is not proof.
//
// Needs: API up (docker compose up -d db api), a proxy to it on 18080 (host 8080 is llama-server):
//   docker run -d --name anm-api-proxy --network anmates_default -p 127.0.0.1:18080:8080 alpine/socat tcp-listen:8080,fork,reuseaddr tcp:api:8080
// a web build served on 54190:
//   flutter build web --dart-define=API_BASE_URL=http://127.0.0.1:18080 --dart-define=V2_DEBUG_NAV=true
//   (cd build/web && python -m http.server 54190 --bind 127.0.0.1)
// then: DEV_BYPASS_SECRET=... NODE_PATH=<dir with playwright> node tool/e2e/ui_flows.js
// Screenshots go to $TMP/anmates-ui-e2e.
const { chromium } = require('playwright');
const path = require('path');
const { execSync } = require('child_process');
const API = 'http://127.0.0.1:18080/api/v1';
const APP = 'http://127.0.0.1:54190/';
const SHOTS = path.join(require('os').tmpdir(), 'anmates-ui-e2e');
const SECRET = process.env.DEV_BYPASS_SECRET;
const results = [];
const check = (name, ok, extra = '') => { results.push(`${ok ? 'PASS' : 'FAIL'} ${name} ${extra}`); };

async function call(method, p, token, body) {
  const r = await fetch(API + p, {
    method, headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: 'Bearer ' + token } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  const j = await r.json().catch(() => ({}));
  return { status: r.status, data: j.data };
}
async function user(name) {
  const phone = '+8455' + String(Date.now()).slice(-9) + Math.floor(Math.random() * 10);
  const r = await call('POST', '/auth/dev-login', null, { secret: SECRET, phone, name });
  return { token: r.data.access_token, refresh: r.data.refresh_token, id: r.data.user.id, name };
}

(async () => {
  require('fs').mkdirSync(SHOTS, { recursive: true });
  const a = await user('UI Anh'), b = await user('UI Bảo Châu'), c = await user('UI Cường Chặn');
  for (const u of [a, b]) for (const [n, k] of [['Phở Thìn', 'pho'], ['Cơm tấm', 'com']])
    await call('POST', '/wishlist', u.token, { food_name: n, food_category: k });
  await call('POST', '/swipes', a.token, { target_id: b.id, liked: true });
  const m = await call('POST', '/swipes', b.token, { target_id: a.id, liked: true });
  const mid = m.data.match.id;
  const when = new Date(Date.now() + 36e5 * 30).toISOString();
  await call('POST', `/matches/${mid}/booking`, b.token, { restaurant_name: 'Phở Thìn Lò Đúc', scheduled_at: when });
  await call('POST', `/matches/${mid}/booking/confirm`, a.token);
  await call('POST', `/matches/${mid}/rating`, b.token, { stars: 4 });
  await call('POST', '/blocks', a.token, { user_id: c.id });

  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 402, height: 874 } });
  const errs = [];
  page.on('pageerror', (e) => errs.push(e.message));
  await page.goto(APP);
  await page.evaluate(([t, r, id]) => {
    localStorage.setItem('flutter.access_token', JSON.stringify(t));
    localStorage.setItem('flutter.refresh_token', JSON.stringify(r));
    localStorage.setItem('flutter.user_id', JSON.stringify(id));
  }, [a.token, a.refresh, a.id]);
  await page.goto(APP + '?v2screen=home');
  await page.waitForTimeout(5000);
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await page.waitForTimeout(1000);
  const shot = (n) => page.screenshot({ path: path.join(SHOTS, n + '.png') });
  const tap = async (name, role) => {
    const loc = role ? page.getByRole(role, { name }) : page.getByText(name, { exact: true });
    await loc.last().click({ timeout: 8000 });
    await page.waitForTimeout(1500);
  };
  const visible = (text) => page.getByText(text).first().isVisible().catch(() => false);

  try {
    // ── Me: real stats + blocked list + unblock ──
    await tap('Tôi');
    await page.waitForTimeout(1500);
    await shot('1-me');
    check('me shows meals label', await visible('bữa đã ăn'));
    check('me blocked list shows C', await visible(c.name));
    await page.getByText(c.name).first().scrollIntoViewIfNeeded().catch(() => {});
    await shot('1b-me-blocked');
    await tap('Bỏ chặn');
    await shot('2-unblock-confirm');
    await tap('Bỏ chặn', 'button');
    await page.waitForTimeout(1500);
    await shot('3-after-unblock');
    const bl = await call('GET', '/blocks', a.token);
    check('API: unblock via UI', bl.data.length === 0, JSON.stringify(bl.data.map((x) => x.name)));

    // ── Chat → Bill → Rate (partner's 4★ appears after A rates) ──
    await tap('Tin nhắn');
    await page.getByText(b.name).first().click(); await page.waitForTimeout(2500);
    await shot('4-chat');
    await page.getByText(/Phở Thìn Lò Đúc/).first().click(); await page.waitForTimeout(2000);
    await shot('5-bill');
    check('bill shows rate CTA', await visible('Đánh giá bữa ăn'));
    await tap('Đánh giá bữa ăn');
    await shot('6-rate');
    await tap('Gửi rate riêng tư');
    await page.waitForTimeout(2000);
    await shot('7-rated');
    const rv = await call('GET', `/matches/${mid}/rating`, a.token);
    check('API: rating saved via UI', rv.data.mine && rv.data.both_rated, JSON.stringify(rv.data));
    check('rate shows partner line', await visible(`${b.name} đã rate ★★★★`));
    check('rate CTA says both rated', await visible('Cả hai đã rate · bấm để sửa'));
    check('rate CTA no longer says waiting', !(await visible('chờ ' + b.name)));

    // ── Report + Unmatch from the chat menu ──
    await tap('Tin nhắn');
    await page.getByText(b.name).first().click(); await page.waitForTimeout(2500);
    await page.getByRole('button', { name: /show menu/i }).click();
    await page.waitForTimeout(800);
    await tap('Báo cáo', 'menuitem');
    await shot('8-report-reasons');
    await tap('Không đến buổi hẹn');
    await page.waitForTimeout(1200);
    await shot('9-reported');
    const reports = execSync(`docker exec anmates-db-1 psql -U postgres -d anmates -tAc "SELECT reason FROM user_reports WHERE reporter_id='${a.id}'"`).toString().trim();
    check('DB: report via UI', reports === 'no_show', reports);

    await page.getByRole('button', { name: /show menu/i }).click();
    await page.waitForTimeout(800);
    await tap('Bỏ ghép', 'menuitem');
    await shot('10-unmatch-confirm');
    await tap('Đồng ý', 'button');
    await page.waitForTimeout(1500);
    await shot('11-after-unmatch');
    const cv = await call('GET', '/conversations', b.token);
    check('API: unmatch via UI (B side)', !cv.data.some((x) => x.match_id === mid));
  } catch (e) {
    await shot('ERROR');
    results.push('ERROR ' + e.message.split('\n')[0]);
  }
  results.push('page errors: ' + (errs.length ? errs.join(' | ') : 'none'));
  console.log(results.join('\n'));
  await browser.close();
})().catch((e) => { console.error('FAILED', e.message); process.exit(1); });
