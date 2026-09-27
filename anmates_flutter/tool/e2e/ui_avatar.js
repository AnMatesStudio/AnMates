// Real-app UI e2e (docs/e2e-test-cases.md UI-25): Me → avatar → pick an illustration → saved; then upload a
// photo → drag + zoom in the crop → "Dùng ảnh này" → stored on our API as a 512×512 JPEG, shown on Me, on the
// Explore header and on a partner's Quẹt card.
// Needs the API with DEV_MODE + DEV_BYPASS_SECRET + DISABLE_RATE_LIMIT (see ui_flows.js) and a web build with
// V2_DEBUG_NAV pointed at it:
//   flutter build web --dart-define=API_BASE_URL=$API_ORIGIN --dart-define=V2_DEBUG_NAV=true
//   (cd build/web && python3 -m http.server 54190 --bind 127.0.0.1)
// Run: DEV_BYPASS_SECRET=... PHOTO=<a .jpg> NODE_PATH=<dir with playwright or playwright-core>
//      [API_ORIGIN=http://127.0.0.1:18080 PW=playwright-core CHROME=<chrome binary>] node tool/e2e/ui_avatar.js
const { chromium } = require(process.env.PW || 'playwright');
const path = require('path');
const API_ORIGIN = process.env.API_ORIGIN || 'http://127.0.0.1:18080';
const API = API_ORIGIN + '/api/v1';
const APP = process.env.APP || 'http://127.0.0.1:54190/';
const PHOTO = process.env.PHOTO;
const SHOTS = process.env.SHOTS || path.join(require('os').tmpdir(), 'anmates-ui-avatar');
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
const avatarOf = async (u) => (await call('GET', '/profile', u.token)).data.avatar_url;

(async () => {
  require('fs').mkdirSync(SHOTS, { recursive: true });
  // Same unique tastes, so B's deck holds A.
  const tags = [`ava-${Date.now()}-a`, `ava-${Date.now()}-b`];
  const a = await devUser('UI Avatar A'), b = await devUser('UI Avatar B');
  for (const u of [a, b]) await call('PATCH', '/profile/preferences', u.token, { food_tags: tags, vibe_tags: [] });

  const browser = await chromium.launch(process.env.CHROME ? { executablePath: process.env.CHROME } : {});
  const page = await browser.newPage({ viewport: { width: 402, height: 874 } });
  const errs = [];
  page.on('pageerror', (e) => errs.push(e.message));
  const shot = (n) => page.screenshot({ path: path.join(SHOTS, n + '.png') });
  const vis = (t, exact = true) => page.getByText(t, { exact }).first().isVisible().catch(() => false);
  const clickBox = async (locator) => {
    const b = await locator.first().boundingBox();
    await page.mouse.click(b.x + b.width / 2, b.y + b.height / 2);
    await page.waitForTimeout(900);
  };
  const signIn = async (u, screen) => {
    await page.goto(APP);
    await page.evaluate(([t, r, id]) => {
      localStorage.setItem('flutter.access_token', JSON.stringify(t));
      localStorage.setItem('flutter.refresh_token', JSON.stringify(r));
      localStorage.setItem('flutter.user_id', JSON.stringify(id));
    }, [u.token, u.refresh, u.id]);
    await page.goto(APP + '?v2screen=' + screen);
    // Boot time varies (the Firebase SDK loads from gstatic): wait for the
    // semantics switch rather than a fixed sleep, then for the tree it turns on.
    await page.waitForSelector('flt-semantics-placeholder', { state: 'attached', timeout: 30000 });
    await page.waitForTimeout(1500);
    await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
    await page.waitForSelector('flt-semantics', { state: 'attached', timeout: 10000 });
    await page.waitForTimeout(1000);
  };

  try {
    await signIn(a, 'me');
    await shot('1-me-default');
    check('Me shows the avatar as a button', await page.getByRole('button', { name: 'Đổi ảnh đại diện' }).first().isVisible());

    // ── An illustration ──
    await clickBox(page.getByRole('button', { name: 'Đổi ảnh đại diện' }));
    await shot('2-avatar-screen');
    check('avatar screen: title, upload, 11 illustrations',
      (await vis('Ảnh đại diện')) && (await vis('Tải ảnh lên')) &&
      (await page.getByRole('button', { name: /^Ảnh có sẵn \d+$/ }).count()) === 11);
    await clickBox(page.getByRole('button', { name: 'Ảnh có sẵn 4' }));
    await shot('3-sample-picked');
    await clickBox(page.getByText('Lưu ảnh đại diện'));
    await page.waitForTimeout(800);
    check('sample saved as asset:…/sample-3.png', (await avatarOf(a)) === 'asset:assets/v2/avatars/sample-3.png', await avatarOf(a));
    check('back on Me', await vis('Quán bạn đã đi'));
    await shot('4-me-sample');

    // ── A photo, cropped ──
    await clickBox(page.getByRole('button', { name: 'Đổi ảnh đại diện' }));
    const chooser = page.waitForEvent('filechooser', { timeout: 10000 });
    await clickBox(page.getByText('Tải ảnh lên'));
    await (await chooser).setFiles(PHOTO);
    await page.waitForTimeout(2500);
    await shot('5-crop');
    check('crop step shown', (await vis('Dùng ảnh này')) && (await vis('Chọn ảnh khác')));
    await clickBox(page.getByRole('button', { name: 'Phóng to' }));
    await clickBox(page.getByRole('button', { name: 'Phóng to' }));
    // Drag the photo inside the square (centre of the sheet's upper half).
    await page.mouse.move(200, 330); await page.mouse.down();
    await page.mouse.move(150, 290, { steps: 10 }); await page.mouse.up();
    await page.waitForTimeout(500);
    await shot('6-crop-zoomed');
    await clickBox(page.getByText('Dùng ảnh này'));
    await page.waitForTimeout(2000);
    const url = await avatarOf(a);
    check('upload saved at /users/<id>/avatar?v=…', typeof url === 'string' && url.startsWith(`/api/v1/users/${a.id}/avatar?v=`), url);
    const img = await fetch(API_ORIGIN + url);
    const buf = Buffer.from(await img.arrayBuffer());
    // JPEG SOF0/SOF2 frame: height and width follow the marker.
    let w = 0, h = 0;
    for (let i = 2; i < buf.length - 9; i++) {
      if (buf[i] === 0xff && (buf[i + 1] === 0xc0 || buf[i + 1] === 0xc2)) { h = buf.readUInt16BE(i + 5); w = buf.readUInt16BE(i + 7); break; }
    }
    check('served as a 512×512 JPEG', img.status === 200 && img.headers.get('content-type') === 'image/jpeg' && w === 512 && h === 512, `${img.status} ${w}x${h}`);
    await shot('7-me-photo');
    check('back on Me with a toast', (await vis('Quán bạn đã đi')) && (await vis('Đã cập nhật ảnh đại diện')));

    await page.goto(APP + '?v2screen=home');
    await page.waitForTimeout(4000);
    await shot('8-home-header');

    // ── What a partner sees ──
    await signIn(b, 'swipe');
    await page.waitForTimeout(1500);
    await shot('9-partner-deck');
    // The card is one merged semantics node: its name sits in the aria-label, not in text.
    const cardLabels = await page.$$eval('flt-semantics', (els) => els.map((e) => e.getAttribute('aria-label') || ''));
    check("partner's deck shows A's card", cardLabels.some((l) => l.includes('UI Avatar A')));
  } catch (e) {
    await shot('ERROR');
    results.push('ERROR ' + e.message.split('\n')[0]);
  }
  results.push('page errors: ' + (errs.length ? errs.join(' | ') : 'none'));
  results.push('screenshots: ' + SHOTS);
  console.log(results.join('\n'));
  await browser.close();
})().catch((e) => { console.error('FAILED', e.message); process.exit(1); });
