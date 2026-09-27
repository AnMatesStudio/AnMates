// Real-app UI e2e (docs/e2e-test-cases.md UI-19): the "Match filter" screen's 0–200 km radius slider narrows the
// deck by distance and keeps people without a location. Setup: same as ui_flows.js (API + proxy on 18080 + web build
// with V2_DEBUG_NAV on 54190). Run: DEV_BYPASS_SECRET=... NODE_PATH=<dir with playwright> node tool/e2e/ui_match_radius.js
const { chromium } = require('playwright');
const path = require('path');
const API = 'http://127.0.0.1:18080/api/v1';
const APP = 'http://127.0.0.1:54190/';
const SHOTS = path.join(require('os').tmpdir(), 'anmates-ui-radius');
const SECRET = process.env.DEV_BYPASS_SECRET;
const results = [];
const check = (name, ok, extra = '') => results.push(`${ok ? 'PASS' : 'FAIL'} ${name} ${extra}`);

async function call(method, p, token, body) {
  const r = await fetch(API + p, {
    method, headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: 'Bearer ' + token } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  const j = await r.json().catch(() => ({}));
  return { status: r.status, data: j.data };
}
async function devUser(name) {
  const phone = '+8422' + String(Date.now()).slice(-9) + Math.floor(Math.random() * 10);
  const r = await call('POST', '/auth/dev-login', null, { secret: SECRET, phone, name });
  return { token: r.data.access_token, refresh: r.data.refresh_token, id: r.data.user.id };
}

(async () => {
  require('fs').mkdirSync(SHOTS, { recursive: true });
  // A in the middle; B ~10 km away, C ~50 km away, D has no location. Unique tastes keep other users out of the deck.
  const stamp = Date.now(), tags = [`rad-${stamp}-a`, `rad-${stamp}-b`];
  const a = await devUser('UI Radius A'), b = await devUser('UI Gần 10km'), c = await devUser('UI Xa 50km'), d = await devUser('UI Không vị trí');
  for (const u of [a, b, c, d]) await call('PATCH', '/profile/preferences', u.token, { food_tags: tags, vibe_tags: [] });
  const lat = -40 + (stamp % 8000) / 100, lng = -170 + ((stamp / 8000 | 0) % 34000) / 100;
  await call('PUT', '/me/location', a.token, { lat, lng, district: 'Radius' });
  await call('PUT', '/me/location', b.token, { lat: lat + 0.09, lng, district: 'Radius' });
  await call('PUT', '/me/location', c.token, { lat: lat + 0.45, lng, district: 'Radius' });

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
  await page.goto(APP + '?v2screen=filters');
  await page.waitForTimeout(5000);
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await page.waitForTimeout(1000);
  const count = async () => {
    const t = await page.getByText(/Xem \d+ mates phù hợp/).first().textContent().catch(() => '');
    return Number((t.match(/Xem (\d+)/) || [])[1] ?? -1);
  };
  try {
    await page.screenshot({ path: path.join(SHOTS, '1-filter.png') });
    check('title is "Match filter"', await page.getByText('Match filter', { exact: true }).first().isVisible());
    check('default ≤ 200 km shows all 3', (await count()) === 3, 'n=' + (await count()));
    const slider = await page.getByRole('slider').first().boundingBox();
    // The semantics box is only the thumb (at max it sits on the track's right end). The track's left end is the
    // card's inner padding (38 + 24 px at this 402 px viewport). Drag the thumb like a user.
    const right = slider.x + slider.width / 2, left = 62;
    const x = (f) => left + (right - left) * f;
    const y = slider.y + slider.height / 2;
    const drag = async (to) => {
      await page.mouse.move(x(1), y);
      await page.mouse.down();
      await page.mouse.move(x(to), y, { steps: 12 });
      await page.mouse.up();
    };
    await drag(0.1);
    await page.waitForTimeout(1200);
    await page.screenshot({ path: path.join(SHOTS, '2-20km.png') });
    check('≈20 km keeps B (10 km) + D (no location), drops C (50 km)', (await count()) === 2, 'n=' + (await count()));
    await page.mouse.move(x(0.1), y); await page.mouse.down(); await page.mouse.move(x(0.02), y, { steps: 8 }); await page.mouse.up();
    await page.waitForTimeout(1200);
    check('≈5 km keeps only D (unknown)', (await count()) === 1, 'n=' + (await count()));
    const rb = await page.getByText(/Đặt lại/).first().boundingBox();
    await page.mouse.click(rb.x + rb.width / 2, rb.y + rb.height / 2);
    await page.waitForTimeout(1200);
    check('reset restores all 3', (await count()) === 3, 'n=' + (await count()));

    // ── Area section: compact + "Thêm" + diacritic-insensitive search ──
    const vis = (t, exact = true) => page.getByText(t, { exact }).first().isVisible().catch(() => false);
    check('areas collapsed: 6 chips + "+ Thêm (5)" (11 areas)', await vis('+ Thêm (5)'));
    check('areas collapsed: first chip "Bình Dương" visible', await vis('Bình Dương'));
    await page.screenshot({ path: path.join(SHOTS, '3-areas-collapsed.png') });
    const mb = await page.getByText(/\+ Thêm \(\d+\)/).first().boundingBox();
    await page.mouse.click(mb.x + mb.width / 2, mb.y + mb.height / 2);
    await page.waitForTimeout(1000);
    check('areas expanded: "Thu gọn" chip shown', await vis('Thu gọn'));
    await page.screenshot({ path: path.join(SHOTS, '4-areas-expanded.png') });
    const lb = await page.getByText(/Thu gọn/).first().boundingBox();
    await page.mouse.click(lb.x + lb.width / 2, lb.y + lb.height / 2);
    await page.waitForTimeout(800);
    // Flutter web creates the <input> only on focus: tap the field where its hint is drawn.
    // Its hint is not in the semantics tree; the field sits ~40 px below the "Khu vực / Quận" label.
    const hb = await page.getByText('Khu vực / Quận', { exact: true }).first().boundingBox();
    await page.mouse.click(200, hb.y + 40);
    await page.waitForTimeout(500);
    await page.keyboard.type('thu duc', { delay: 20 });
    await page.waitForTimeout(1000);
    await page.screenshot({ path: path.join(SHOTS, '5-areas-search.png') });
    check('search "thu duc" finds "Thủ Đức"', await vis('Thủ Đức'));
    check('search hides non-matching "Bình Dương"', !(await vis('Bình Dương')));
    await page.keyboard.press('Control+A'); await page.keyboard.type('xyz khong co', { delay: 15 });
    await page.waitForTimeout(800);
    check('no-match message', await vis(/Không tìm thấy khu vực/, false));
  } catch (e) {
    await page.screenshot({ path: path.join(SHOTS, 'ERROR.png') });
    results.push('ERROR ' + e.message.split('\n')[0]);
  }
  results.push('page errors: ' + (errs.length ? errs.join(' | ') : 'none'));
  console.log(results.join('\n'));
  await browser.close();
})().catch((e) => { console.error('FAILED', e.message); process.exit(1); });
