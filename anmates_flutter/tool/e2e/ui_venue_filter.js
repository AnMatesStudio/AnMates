// Real-app UI e2e (docs/e2e-test-cases.md UI-24): Explore's tune icon opens "Lọc quán" (venues: radius, dish,
// district, spend per person), not the mates filter; Quẹt has its own filter button for "Match filter".
// Needs only GET /api/v1/venues, so it runs signed out against any build:
//   local: flutter build web --dart-define=API_BASE_URL=https://app.anmates.site --dart-define=V2_DEBUG_NAV=true
//          (cd build/web && python3 -m http.server 54190 --bind 127.0.0.1)
//   prod:  APP=https://app.anmates.site/ (walks through onboarding instead of ?v2screen=home)
// Run: NODE_PATH=<dir with playwright or playwright-core> [PW=playwright-core CHROME=<chrome binary>] node tool/e2e/ui_venue_filter.js
const { chromium } = require(process.env.PW || 'playwright');
const path = require('path');
const APP = process.env.APP || 'http://127.0.0.1:54190/';
const DEBUG_NAV = !/anmates\.site/.test(APP);
const SHOTS = process.env.SHOTS || path.join(require('os').tmpdir(), 'anmates-ui-venue-filter');
const results = [];
const check = (name, ok, extra = '') => results.push(`${ok ? 'PASS' : 'FAIL'} ${name} ${extra}`);

(async () => {
  require('fs').mkdirSync(SHOTS, { recursive: true });
  const browser = await chromium.launch(process.env.CHROME ? { executablePath: process.env.CHROME } : {});
  // Nhà hát Thành phố, Q1 — a public landmark in the catalogue's densest area.
  const context = await browser.newContext({
    viewport: { width: 402, height: 874 },
    geolocation: { latitude: 10.7769, longitude: 106.7031 },
    permissions: ['geolocation'],
  });
  const page = await context.newPage();
  const errs = [];
  page.on('pageerror', (e) => errs.push(e.message));
  const shot = (n) => page.screenshot({ path: path.join(SHOTS, n + '.png') });
  const vis = (t, exact = true) => page.getByText(t, { exact }).first().isVisible().catch(() => false);
  const click = async (t, exact = true) => {
    const b = await page.getByText(t, { exact }).first().boundingBox();
    await page.mouse.click(b.x + b.width / 2, b.y + b.height / 2);
    await page.waitForTimeout(900);
  };
  const clickLabel = async (label) => {
    const b = await page.getByRole('button', { name: label }).first().boundingBox();
    await page.mouse.click(b.x + b.width / 2, b.y + b.height / 2);
    await page.waitForTimeout(900);
  };
  const venueCount = async () => {
    const t = await page.getByText(/Xem \d+ quán phù hợp/).first().textContent().catch(() => '');
    return Number((t.match(/Xem (\d+)/) || [])[1] ?? -1);
  };

  await page.goto(APP + (DEBUG_NAV ? '?v2screen=home' : ''));
  await page.waitForTimeout(6000);
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await page.waitForTimeout(1000);
  try {
    if (!DEBUG_NAV) {
      for (const step of ['CÙNG ĂN THÔI', 'Bắt đầu gom kèo', 'Xem ai đang gom kèo', 'Tiếp tục', 'Vào Ăn Mates']) {
        await click(step, false); // a button's label can carry its arrow too ("CÙNG ĂN THÔI →")
      }
    }
    await page.waitForTimeout(3000);
    await shot('1-home');
    check('Explore loaded', await vis('Quán gần bạn'));

    // ── Venue filter from Explore ──
    await clickLabel(/Lọc quán/);
    await page.waitForTimeout(800);
    await shot('2-venue-filter');
    check('tune icon opens "Lọc quán"', await vis('Lọc quán'));
    check('no mates filter here ("Match filter", "Vibe sống")', !(await vis('Match filter')) && !(await vis('Vibe sống')));
    check('venue sections shown', (await vis('Khoảng cách')) && (await vis('Món ăn')) && (await vis('Khu vực / Quận')) && (await vis('Khoảng giá / người')));
    const n0 = await venueCount();
    check('CTA counts venues in range', n0 > 0, 'n=' + n0);

    await click('Quận 1');
    const n1 = await venueCount();
    check('district "Quận 1" narrows the count', n1 > 0 && n1 <= n0, `n=${n0}→${n1}`);
    await click('>350k');
    const n2 = await venueCount();
    check('spend ">350k" narrows further', n2 >= 0 && n2 <= n1, `n=${n1}→${n2}`);
    await shot('3-venue-filter-picked');

    await click(/Xem \d+ quán phù hợp/, false);
    await page.waitForTimeout(800);
    await shot('4-home-filtered');
    check('CTA returns to Explore', await vis('Quán gần bạn'));
    const badge = await page.getByRole('button', { name: /Lọc quán/ }).first().textContent().catch(() => '');
    const label = await page.getByRole('button', { name: /Lọc quán/ }).first().getAttribute('aria-label').catch(() => '');
    check('tune icon badge shows 2', /2/.test(`${badge} ${label}`), JSON.stringify(`${badge}|${label}`));

    await clickLabel(/Lọc quán/);
    await click('Đặt lại');
    check('"Đặt lại" restores the full count', (await venueCount()) === n0, 'n=' + (await venueCount()));
    await click('‹');
    check('back button returns to Explore', await vis('Quán gần bạn'));

    // ── Mates filter from Quẹt ──
    await click('Quẹt');
    await page.waitForTimeout(1500);
    await clickLabel(/Lọc mates/);
    await page.waitForTimeout(800);
    await shot('5-match-filter');
    check('Quẹt filter button opens "Match filter"', (await vis('Match filter')) && (await vis('Vibe sống')));
    await click('‹');
    await page.waitForTimeout(800);
    check('its back button returns to Quẹt', await vis('Gửi lời mời'));
    await shot('6-swipe');
  } catch (e) {
    await shot('ERROR');
    results.push('ERROR ' + e.message.split('\n')[0]);
  }
  results.push('page errors: ' + (errs.length ? errs.join(' | ') : 'none'));
  results.push('screenshots: ' + SHOTS);
  console.log(results.join('\n'));
  await browser.close();
})().catch((e) => { console.error('FAILED', e.message); process.exit(1); });
