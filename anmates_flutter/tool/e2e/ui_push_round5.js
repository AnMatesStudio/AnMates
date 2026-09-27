// Real-app UI e2e, round 5 (docs/e2e-test-cases.md UI-25..UI-28): self-hosted notifications in a real browser.
// Realtime /ws/notify updates the bell within seconds (no polling), a hidden tab gets a system notification,
// the Inbox prompt + Me switch, and a real Web Push subscription stored server-side.
// Setup: same as ui_flows.js (API with VAPID keys in .env + proxy on 18080 + web build on 54190).
// Run: DEV_BYPASS_SECRET=... NODE_PATH=<dir with playwright> node tool/e2e/ui_push_round5.js
const { chromium } = require('playwright');
const path = require('path');
const { execSync } = require('child_process');
const API = 'http://127.0.0.1:18080/api/v1';
const APP = 'http://127.0.0.1:54190/';
const SHOTS = path.join(require('os').tmpdir(), 'anmates-ui-e2e-5');
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
  const phone = '+8499' + String(Date.now()).slice(-9) + Math.floor(Math.random() * 10);
  const r = await call('POST', '/auth/dev-login', null, { secret: SECRET, phone, name });
  return { token: r.data.access_token, refresh: r.data.refresh_token, id: r.data.user.id, name };
}

(async () => {
  require('fs').mkdirSync(SHOTS, { recursive: true });
  const a = await devUser('UI5 Anh'), b = await devUser('UI5 Bình');
  for (const u of [a, b]) for (const [n, k] of [['Phở', 'pho'], ['Cơm', 'com']])
    await call('POST', '/wishlist', u.token, { food_name: n, food_category: k });

  // Full Chromium (new headless): the default headless shell reports Notification.permission 'denied' whatever
  // permissions are granted, so notifications could never be tested there.
  // Full Chromium (new headless) with a real, persistent profile: the default headless shell reports
  // Notification.permission 'denied', and normal Playwright contexts are incognito, where Chrome deliberately
  // has no Push API. No notification permission yet: the Inbox card must ask; it is granted when "Bật" is tapped.
  const profile = require('fs').mkdtempSync(path.join(require('os').tmpdir(), 'anm-push-profile-'));
  const ctx = await chromium.launchPersistentContext(profile, { channel: 'chromium', viewport: { width: 402, height: 874 } });
  const browser = { close: () => ctx.close() };
  // Record every system notification the page or its service worker registration shows; let the test flip visibility.
  await ctx.addInitScript(() => {
    window.__notified = [];
    window.__hidden = false;
    Object.defineProperty(document, 'visibilityState', { configurable: true, get: () => (window.__hidden ? 'hidden' : 'visible') });
    const Orig = window.Notification;
    if (Orig) {
      const Rec = function (title, opts) { window.__notified.push({ via: 'Notification', title, body: opts && opts.body }); return new Orig(title, opts); };
      Object.defineProperty(Rec, 'permission', { get: () => Orig.permission });
      Rec.requestPermission = Orig.requestPermission.bind(Orig);
      window.Notification = Rec;
    }
    if (window.ServiceWorkerRegistration) {
      const orig = ServiceWorkerRegistration.prototype.showNotification;
      ServiceWorkerRegistration.prototype.showNotification = function (title, opts) {
        window.__notified.push({ via: 'sw', title, body: opts && opts.body });
        return orig.call(this, title, opts);
      };
    }
  });
  const page = ctx.pages()[0] || await ctx.newPage();
  const errs = [];
  page.on('pageerror', (e) => errs.push(e.message));
  const consoleLog = [];
  page.on('console', (m) => { if (/anmatesPush|push|unsubscribe/i.test(m.text())) consoleLog.push(m.type() + ': ' + m.text()); });
  const shot = (n) => page.screenshot({ path: path.join(SHOTS, n + '.png') });
  const vis = (t) => page.getByText(t).first().isVisible().catch(() => false);
  const clickText = async (re) => {
    const bb = await page.getByText(re).first().boundingBox();
    await page.mouse.click(bb.x + bb.width / 2, bb.y + bb.height / 2);
    await page.waitForTimeout(1200);
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
    await page.waitForTimeout(1500);
    const bell = () => page.getByRole('button', { name: /Thông báo, \d+ chưa đọc/ }).first().isVisible().catch(() => false);
    check('no unread badge before anything happens', !(await bell()));

    // ── 1. Realtime: a match makes the badge appear within seconds (polling would take up to 30 s) ──
    await call('POST', '/swipes', a.token, { target_id: b.id, liked: true });
    const t0 = Date.now();
    await call('POST', '/swipes', b.token, { target_id: a.id, liked: true });
    let seen = false;
    while (Date.now() - t0 < 6000 && !(seen = await bell())) await page.waitForTimeout(250);
    await shot('01-badge-realtime');
    check('bell badge appears via realtime (< 6 s)', seen, `after ${Date.now() - t0} ms`);

    // ── 3. Inbox prompt ──
    await clickText(/^Tin nhắn$/);
    await page.waitForTimeout(1500);
    await shot('02-inbox-prompt');
    check('inbox shows the "turn on notifications" card', await vis(/Bật thông báo để không lỡ tin nhắn/));

    // ── 4. Turn on Web Push from the card → real browser subscription stored for this user ──
    await ctx.grantPermissions(['notifications'], { origin: APP.replace(/\/$/, '') });
    await clickText(/^Bật$/);
    let endpoint = '';
    const t2 = Date.now();
    while (Date.now() - t2 < 15000 && !(endpoint = sql(`SELECT endpoint FROM push_subscriptions WHERE user_id='${a.id}' LIMIT 1`))) await page.waitForTimeout(500);
    await shot('03-after-enable');
    const host = endpoint ? new URL(endpoint).host : '';
    check('Web Push subscription stored (real browser push service)', !!endpoint, host || 'none');
    check('prompt card gone after enabling', !(await vis(/Bật thông báo để không lỡ tin nhắn/)));

    // ── 4a. Real end-to-end Web Push: our server → the browser vendor's push service → our service worker ──
    // The page stays VISIBLE, so the realtime channel shows nothing; any notification shown by the worker came via Web Push.
    const sw = ctx.serviceWorkers().find((w) => w.url().includes('/push/sw.js'));
    if (!sw) {
      check('push service worker registered', false);
    } else {
      await sw.evaluate(() => {
        self.__shown = [];
        const orig = self.registration.showNotification.bind(self.registration);
        self.registration.showNotification = (t, o) => { self.__shown.push((o && o.body) || t); return orig(t, o); };
      });
      await call('POST', `/matches/${sql(`SELECT id FROM matches WHERE (user_a_id='${a.id}' AND user_b_id='${b.id}') OR (user_a_id='${b.id}' AND user_b_id='${a.id}')`)}/rating`, b.token, { stars: 5 });
      let shownBySw = [];
      const t3 = Date.now();
      while (Date.now() - t3 < 25000) {
        shownBySw = await sw.evaluate(() => self.__shown);
        if (shownBySw.length) break;
        await page.waitForTimeout(500);
      }
      check('Web Push delivered through the real push service to our service worker', shownBySw.some((x) => /UI5 Bình đã đánh giá bữa ăn/.test(x)),
        `${JSON.stringify(shownBySw)} after ${Date.now() - t3} ms`);
    }

    // ── 4b. Hidden tab → system notification from the realtime channel ──
    await page.evaluate(() => { window.__hidden = true; document.dispatchEvent(new Event('visibilitychange')); });
    const mid = sql(`SELECT id FROM matches WHERE (user_a_id='${a.id}' AND user_b_id='${b.id}') OR (user_a_id='${b.id}' AND user_b_id='${a.id}')`);
    const when = new Date(Date.now() + 36e5 * 30).toISOString();
    await call('POST', `/matches/${mid}/booking`, b.token, { restaurant_name: 'Lẩu Phan', scheduled_at: when });
    let notified = [];
    const t1 = Date.now();
    while (Date.now() - t1 < 6000) {
      notified = await page.evaluate(() => window.__notified);
      if (notified.some((n) => /mời bạn đi ăn/.test(n.body || ''))) break;
      await page.waitForTimeout(250);
    }
    check('hidden tab shows a system notification for the booking', notified.some((n) => /UI5 Bình mời bạn đi ăn/.test(n.body || '')), JSON.stringify(notified));
    await page.evaluate(() => { window.__hidden = false; document.dispatchEvent(new Event('visibilitychange')); });

    // ── 5. Me switch reflects it; turning it off removes the subscription ──
    await clickText(/^Tôi$/);
    await page.waitForTimeout(1500);
    await page.getByText('Thông báo đẩy').first().scrollIntoViewIfNeeded().catch(() => {});
    await shot('04-me-switch');
    const swi = page.getByRole('switch', { name: /Thông báo đẩy/ }).first();
    const on = await swi.isChecked().catch(() => null);
    check('Me switch is on', on === true, 'checked=' + on);
    if (endpoint) {
      // Press the centre of the switch's own semantics node.
      const sb = await swi.boundingBox();
      await page.mouse.click(sb.x + sb.width / 2, sb.y + sb.height / 2);
      await page.waitForTimeout(4000);
      await shot('05-after-switch-off');
      check('switch shows off after the tap', (await swi.isChecked().catch(() => null)) === false);
      check('switch off removes the subscription', sql(`SELECT count(*) FROM push_subscriptions WHERE user_id='${a.id}'`) === '0');
    }
  } catch (e) {
    await shot('ERROR');
    results.push('ERROR ' + e.message.split('\n')[0]);
  }
  results.push('page errors: ' + (errs.length ? errs.join(' | ') : 'none'));
  console.log(results.join('\n'));
  await browser.close();
})().catch((e) => { console.error('FAILED', e.message); process.exit(1); });
