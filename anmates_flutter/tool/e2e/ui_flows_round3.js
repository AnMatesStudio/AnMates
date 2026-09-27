// Real-app UI e2e, round 3 (docs/e2e-test-cases.md UI-11..UI-18): sign-up saves onboarding (user reaches decks),
// filters narrow the deck, notifications badge → sheet → chat (image bubble), edit profile, Trust Score,
// visits/reviews, Local Mates invite, delete account. Each UI action is checked against the API or the DB.
//
// Setup: same as ui_flows.js (API + socat proxy on 18080 + web build with V2_DEBUG_NAV served on 54190), plus
// an image the chat can load from the same origin: copy any PNG to build/web/ui-test-image.png.
// Run: DEV_BYPASS_SECRET=... NODE_PATH=<dir with playwright> node tool/e2e/ui_flows_round3.js
// It deletes leftover users from earlier runs of this script (emails ui3+…@anmates.test, names "UI Ba …", "UI Local …").
const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');
const { execSync } = require('child_process');
const API = 'http://127.0.0.1:18080/api/v1';
const APP = 'http://127.0.0.1:54190/';
const SHOTS = path.join(require('os').tmpdir(), 'anmates-ui-e2e-3');
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
  const phone = '+8433' + String(Date.now()).slice(-9) + Math.floor(Math.random() * 10);
  const r = await call('POST', '/auth/dev-login', null, { secret: SECRET, phone, name });
  return { token: r.data.access_token, id: r.data.user.id, name };
}

(async () => {
  fs.mkdirSync(SHOTS, { recursive: true });
  // Earlier (aborted) runs leave onboarded test users that would share this run's wishlist; remove them.
  sql("DELETE FROM users WHERE email LIKE 'ui3+%@anmates.test' OR name LIKE 'UI Ba %' OR name LIKE 'UI Local %' OR name IN ('UI Yên Tĩnh','UI Ồn Vui','UI Bạn Ăn')");
  const stamp = Date.now();
  const email = `ui3+${stamp}@anmates.test`, password = 'supersecret-123';
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 402, height: 874 } });
  const errs = [];
  page.on('pageerror', (e) => errs.push(e.message));
  const shot = (n) => page.screenshot({ path: path.join(SHOTS, n + '.png') });
  const semantics = async () => {
    await page.waitForTimeout(4500);
    await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
    await page.waitForTimeout(800);
  };
  const tap = async (name, role) => {
    const loc = role ? page.getByRole(role, { name }) : page.getByText(name, { exact: true });
    await loc.last().click({ timeout: 8000 });
    await page.waitForTimeout(1500);
  };
  // Flutter web inputs: type like a user — fill() does not always reach the engine.
  const typeInto = async (loc, text) => {
    await loc.click();
    await page.waitForTimeout(300);
    await page.keyboard.press('Control+A');
    await page.keyboard.type(text, { delay: 15 });
    await page.waitForTimeout(300);
  };
  const visible = (text) => page.getByText(text).first().isVisible().catch(() => false);

  try {
    // ── 1. Sign-up through the UI saves the onboarding tastes (account can enter decks) ──
    await page.goto(APP + '?v2screen=auth');
    await semantics();
    if (!(await visible('Tên mọi người sẽ thấy'))) { await page.getByText(/Chưa có tài khoản/).first().click(); await page.waitForTimeout(1200); }
    await typeInto(page.getByRole('textbox', { name: /Tên mọi người sẽ thấy|Tên/ }).first(), 'UI Ba Mới');
    await typeInto(page.getByRole('textbox', { name: /ban@email.com|Email/ }).first(), email);
    await typeInto(page.getByRole('textbox', { name: /Mật khẩu|Password|ký tự/ }).first(), password);
    await shot('01-signup');
    await page.getByRole('button', { name: /^Đăng ký$/ }).last().click();
    await page.waitForTimeout(4000);
    await shot('02-after-signup');
    const row = sql(`SELECT onboarding_done || '|' || array_to_string(food_tags, ',') FROM users WHERE email='${email}'`);
    check('DB: sign-up saved onboarding (onboarding_done + tastes)', /^(t|true)\|.+/.test(row), row);

    const login = await call('POST', '/auth/login', null, { email, password });
    const a = { token: login.data.access_token, id: login.data.user.id, name: 'UI Ba Mới' };

    // ── seed: two candidates sharing A's (unique) tastes, different vibes; a partner with a booking; a local ──
    const tags = [`ui3-${stamp}-a`, `ui3-${stamp}-b`];
    const b1 = await devUser('UI Yên Tĩnh'), b2 = await devUser('UI Ồn Vui');
    for (const u of [a, b1, b2]) await call('PATCH', '/profile/preferences', u.token, { food_tags: tags, vibe_tags: [] });
    await call('PATCH', '/profile/match-prefs', b1.token, { vibe_tags: ['quiet'], price_tier: 1 });
    await call('PATCH', '/profile/match-prefs', b2.token, { vibe_tags: ['lively'], price_tier: 1 });

    const p = await devUser('UI Bạn Ăn');
    for (const u of [a, p]) for (const [n, k] of [['Phở Thìn', 'pho'], ['Cơm tấm', 'com']])
      await call('POST', '/wishlist', u.token, { food_name: n, food_category: k });
    await call('POST', '/swipes', a.token, { target_id: p.id, liked: true });
    const m = await call('POST', '/swipes', p.token, { target_id: a.id, liked: true });
    const mid = m.data.match.id;
    const when = new Date(Date.now() + 36e5 * 30).toISOString();
    await call('POST', `/matches/${mid}/booking`, a.token, { restaurant_name: 'Lẩu Phan', scheduled_at: when });
    await call('POST', `/matches/${mid}/booking/confirm`, p.token);
    await call('POST', `/matches/${mid}/rating`, a.token, { stars: 5, note: 'Đúng giờ, Dễ nói chuyện' });
    await call('POST', '/notifications/read', a.token);
    await call('POST', `/matches/${mid}/rating`, p.token, { stars: 4 }); // → 1 unread 'rating' for A
    sql(`INSERT INTO messages (match_id, sender_id, content, msg_type) VALUES ('${mid}', '${p.id}', '${APP}ui-test-image.png', 'image')`);

    await call('PUT', '/me/location', a.token, { lat: 21.0285, lng: 105.8542, district: 'Hoàn Kiếm' });
    const l = await devUser('UI Local Hà Nội'), lp = await devUser('UI Local Bạn');
    await call('PUT', '/me/location', l.token, { lat: 21.0355, lng: 105.8542, district: 'Hoàn Kiếm' });
    for (const u of [l, lp]) for (const [n, k] of [['Bún chả', 'bun'], ['Phở', 'pho']])
      await call('POST', '/wishlist', u.token, { food_name: n, food_category: k });
    await call('POST', '/swipes', l.token, { target_id: lp.id, liked: true });
    const lm = await call('POST', '/swipes', lp.token, { target_id: l.id, liked: true });
    await call('POST', `/matches/${lm.data.match.id}/booking`, l.token, { restaurant_name: 'Bún chả Hương Liên', scheduled_at: when });
    await call('POST', `/matches/${lm.data.match.id}/booking/confirm`, lp.token);

    // ── 2. Filters narrow the deck ──
    await page.goto(APP + '?v2screen=filters');
    await semantics();
    await shot('03-filters');
    const count = async () => {
      const t = await page.getByText(/Xem \d+ mates phù hợp/).first().textContent().catch(() => '');
      return Number((t.match(/Xem (\d+)/) || [])[1] ?? -1);
    };
    const n0 = await count();
    check('filters: both new candidates counted', n0 >= 2, 'n=' + n0);
    await tap('Yên tĩnh');
    await shot('04-filter-quiet');
    check('filters: vibe "Yên tĩnh" hides the lively one', (await count()) === n0 - 1);
    await tap('Yên tĩnh');
    check('filters: deselect restores', (await count()) === n0);
    await tap('Ồn vui');
    check('filters: vibe "Ồn vui" hides the quiet one', (await count()) === n0 - 1);

    // ── 3. Notifications: badge → sheet → tap opens chat (image bubble) ──
    await page.goto(APP + '?v2screen=home');
    await semantics();
    await shot('05-home-badge');
    const bell = page.getByRole('button', { name: /Thông báo, \d+ chưa đọc/ });
    check('home: bell shows unread badge', await bell.first().isVisible().catch(() => false));
    await bell.first().click();
    await page.waitForTimeout(1500);
    await shot('06-notif-sheet');
    check('sheet: rating notification listed', await visible('UI Bạn Ăn đã đánh giá bữa ăn — rate lại để xem'));
    const unread = await call('GET', '/notifications', a.token);
    check('API: opening the sheet marked all read', unread.data.unread === 0, 'unread=' + unread.data.unread);
    await page.getByText('UI Bạn Ăn đã đánh giá bữa ăn — rate lại để xem').first().click();
    await page.waitForTimeout(3000);
    await shot('07-chat-from-notif');
    check('notification opened the chat', await visible('UI Bạn Ăn'));
    check('chat: attach-photo button present', await page.getByRole('button', { name: /Gửi ảnh/ }).first().isVisible().catch(() => false)
      || await page.getByText('Gửi ảnh').first().isVisible().catch(() => false));

    // ── 4. Me: edit profile, trust, visits, reviews ──
    await tap('Tôi');
    await page.waitForTimeout(1500);
    await shot('08-me');
    check('me: visit "Lẩu Phan" listed', await visible('Lẩu Phan'));
    check('me: review note listed', await visible('Đúng giờ, Dễ nói chuyện'));
    await tap('Sửa hồ sơ');
    await shot('09-edit-sheet');
    await typeInto(page.getByRole('textbox').nth(0), 'UI Ba Đã Sửa');
    await typeInto(page.getByRole('textbox').nth(1), 'Mê lẩu, ghét trễ hẹn');
    await tap('Săn deal');
    await tap('Lưu', 'button');
    await page.waitForTimeout(2000);
    await shot('10-after-save');
    const prof = await call('GET', '/profile', a.token);
    const prefs = await call('GET', '/profile/match-prefs', a.token);
    check('API: profile saved via UI', prof.data.name === 'UI Ba Đã Sửa' && prof.data.bio === 'Mê lẩu, ghét trễ hẹn', `${prof.data.name}|${prof.data.bio}`);
    check('API: vibe saved via UI', (prefs.data.vibe_tags || []).includes('deal'), JSON.stringify(prefs.data));
    check('me: vibe chip shown', await visible('Săn deal'));

    await page.getByText('Trust Score').first().click();
    await page.waitForTimeout(1500);
    await shot('11-trust');
    const tr = await call('GET', '/profile/trust', a.token);
    check('trust screen shows API score', await visible(String(tr.data.score)), 'score=' + tr.data.score);

    // ── 5. Local Mates ──
    await page.goto(APP + '?v2screen=home');
    await semantics();
    await page.getByText(/Tìm Local Mates/).first().click();
    await page.waitForTimeout(2500);
    await shot('12-locals');
    check('locals: nearby local listed', await visible('UI Local Hà Nội'));
    // The card and its pill share one semantics node; press the pill itself (right end of the card).
    const card = await page.getByText(/Mời đi ăn/).last().boundingBox();
    await page.mouse.click(card.x + card.width - 50, card.y + card.height / 2);
    await page.waitForTimeout(1500);
    await shot('12b-after-invite');
    check('locals: invite toast', await visible('Đã gửi lời mời tới UI Local Hà Nội'));
    await page.waitForTimeout(1500);
    const sw = sql(`SELECT liked FROM swipes WHERE user_id='${a.id}' AND target_id='${l.id}'`);
    check('DB: local invite = like', sw === 't', sw);

    // ── 6. Delete account ──
    await tap('Tôi');
    await page.getByText('Xoá tài khoản').first().scrollIntoViewIfNeeded().catch(() => {});
    await tap('Xoá tài khoản');
    await shot('13-delete-confirm');
    await tap('Xoá', 'button');
    await page.waitForTimeout(2500);
    await shot('14-after-delete');
    check('DB: account deleted via UI', sql(`SELECT count(*) FROM users WHERE id='${a.id}'`) === '0');
  } catch (e) {
    await shot('ERROR');
    results.push('ERROR ' + e.message.split('\n')[0]);
  }
  results.push('page errors: ' + (errs.length ? errs.join(' | ') : 'none'));
  console.log(results.join('\n'));
  await browser.close();
})().catch((e) => { console.error('FAILED', e.message); process.exit(1); });
