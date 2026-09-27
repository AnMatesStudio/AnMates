// Real-app UI e2e, round 6 (docs/e2e-test-cases.md UI-31..UI-34): icebreakers in an empty chat, the day-of meal
// status (sent and received in real time) and the no-show rules card. Checked against the DB.
// Setup: same as ui_flows.js (API + proxy on 18080 + web build with V2_DEBUG_NAV on 54190).
// Run: DEV_BYPASS_SECRET=... NODE_PATH=<dir with playwright> node tool/e2e/ui_meal_round6.js
const { chromium } = require('playwright');
const path = require('path');
const { execSync } = require('child_process');
const API = 'http://127.0.0.1:18080/api/v1';
const APP = 'http://127.0.0.1:54190/';
const SHOTS = path.join(require('os').tmpdir(), 'anmates-ui-e2e-6');
const SECRET = process.env.DEV_BYPASS_SECRET;
const results = [];
const check = (name, ok, extra = '') => results.push(`${ok ? 'PASS' : 'FAIL'} ${name} ${extra}`);
const sql = (q) => execSync(`docker exec anmates-db-1 psql -U postgres -d anmates -tAc "${q}"`).toString().trim();

async function call(method, p, token, body) {
  const r = await fetch(API + p, {
    method, headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: 'Bearer ' + token } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  const j = await r.json().catch(() => ({}));
  return { status: r.status, data: j.data };
}
async function devUser(name) {
  const phone = '+8488' + String(Date.now()).slice(-9) + Math.floor(Math.random() * 10);
  const r = await call('POST', '/auth/dev-login', null, { secret: SECRET, phone, name });
  return { token: r.data.access_token, refresh: r.data.refresh_token, id: r.data.user.id, name };
}

(async () => {
  require('fs').mkdirSync(SHOTS, { recursive: true });
  const a = await devUser('UI6 An'), b = await devUser('UI6 Bình');
  for (const u of [a, b]) for (const [n, k] of [['Phở', 'pho'], ['Cơm tấm', 'com']])
    await call('POST', '/wishlist', u.token, { food_name: n, food_category: k });
  await call('POST', '/swipes', a.token, { target_id: b.id, liked: true });
  const mid = (await call('POST', '/swipes', b.token, { target_id: a.id, liked: true })).data.match.id;
  await call('POST', `/matches/${mid}/booking`, b.token, { restaurant_name: 'Phở Thìn Lò Đúc', scheduled_at: new Date(Date.now() + 36e5 * 30).toISOString() });
  await call('POST', `/matches/${mid}/booking/confirm`, a.token);
  sql(`UPDATE bookings SET scheduled_at = now() + interval '40 minutes' WHERE match_id='${mid}'`); // meal is soon

  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 402, height: 874 } });
  const errs = [];
  page.on('pageerror', (e) => errs.push(e.message));
  const shot = (n) => page.screenshot({ path: path.join(SHOTS, n + '.png') });
  const vis = (t) => page.getByText(t).first().isVisible().catch(() => false);
  const clickText = async (re) => {
    const bb = await page.getByText(re).first().boundingBox();
    await page.mouse.click(bb.x + bb.width / 2, bb.y + bb.height / 2);
    await page.waitForTimeout(1500);
  };

  try {
    await page.goto(APP);
    await page.evaluate(([t, r, id]) => {
      localStorage.setItem('flutter.access_token', JSON.stringify(t));
      localStorage.setItem('flutter.refresh_token', JSON.stringify(r));
      localStorage.setItem('flutter.user_id', JSON.stringify(id));
    }, [a.token, a.refresh, a.id]);
    await page.goto(APP + '?v2screen=home');
    await page.waitForTimeout(4500);
    await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
    await page.waitForTimeout(1000);

    // ── 1. Icebreakers in the empty chat; a tap fills the composer, sending posts it ──
    await clickText(/^Tin nhắn$/);
    await page.getByText(b.name).first().click();
    await page.waitForTimeout(3000);
    await shot('01-chat-icebreakers');
    check('empty chat shows "Gợi ý mở lời"', await vis('Gợi ý mở lời'));
    const chip = page.getByText(/phở|cơm tấm/i).first();
    const chipText = (await chip.textContent().catch(() => '')) || '';
    check('a starter mentions a food both like', /phở|cơm tấm/i.test(chipText), chipText);
    await chip.click();
    await page.waitForTimeout(1200);
    // Send it with the send button (right end of the composer row, which now shows the starter text).
    // The composer's text is not in the semantics tree; its row sits right under the booking bar (see 02-sent.png).
    const bar = await page.getByText(/Phở Thìn Lò Đúc/).first().boundingBox();
    await page.mouse.click(402 - 38, bar.y + bar.height / 2 + 57);
    await page.waitForTimeout(2500);
    await shot('02-sent');
    const sent = sql(`SELECT content FROM messages WHERE match_id='${mid}' AND sender_id='${a.id}' ORDER BY created_at DESC LIMIT 1`);
    check('tapped starter was sent as A\'s first message', sent.length > 10 && chipText.includes(sent.slice(0, 15)), sent);

    // ── 2. Bill screen: rules card + day-of status ──
    await page.getByText(/Phở Thìn Lò Đúc/).first().click();
    await page.waitForTimeout(2000);
    await shot('03-bill');
    check('rules card shown', await vis('Luật chơi chống bùng hẹn') && await vis(/trừ 20 điểm Trust Score/));
    check('day-of status section shown', await vis('Hôm nay thế nào?'));
    await clickText(/^Trễ ~10 phút$/);
    await page.waitForTimeout(1500);
    await shot('04-late-sent');
    check('DB: A running_late_10', sql(`SELECT s.status FROM meal_status s JOIN bookings b ON b.id=s.booking_id WHERE b.match_id='${mid}' AND s.user_id='${a.id}'`) === 'running_late_10');
    const nb = await call('GET', '/notifications', b.token);
    check('B notified that A is late', (nb.data.items || []).some((n) => n.kind === 'running_late_10' && n.match_id === mid));

    // ── 3. B says "on my way" → A's screen shows it in real time (no reload) ──
    await call('POST', `/matches/${mid}/booking/status`, b.token, { status: 'on_my_way' });
    let seen = false;
    const t0 = Date.now();
    while (Date.now() - t0 < 8000 && !(seen = await vis(`${b.name}: Đang tới`))) await page.waitForTimeout(300);
    await shot('05-partner-status');
    check('partner status appears live on the bill screen', seen, `${Date.now() - t0} ms`);
  } catch (e) {
    await shot('ERROR');
    results.push('ERROR ' + e.message.split('\n')[0]);
  }
  results.push('page errors: ' + (errs.length ? errs.join(' | ') : 'none'));
  console.log(results.join('\n'));
  await browser.close();
})().catch((e) => { console.error('FAILED', e.message); process.exit(1); });
