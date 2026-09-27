// Real-app UI e2e, round 4 (docs/e2e-test-cases.md UI-20..UI-24): sign-up needs date of birth + consent,
// email verification screen (a known code is planted in the DB — real codes are emailed), legal pages,
// and the admin report queue (suspend). Every UI action is checked against the API or the DB.
// Setup: same as ui_flows.js (API + proxy on 18080 + web build with V2_DEBUG_NAV on 54190).
// Run: DEV_BYPASS_SECRET=... NODE_PATH=<dir with playwright> node tool/e2e/ui_trust_round4.js
const { chromium } = require('playwright');
const path = require('path');
const crypto = require('crypto');
const { execSync } = require('child_process');
const API = 'http://127.0.0.1:18080/api/v1';
const APP = 'http://127.0.0.1:54190/';
const SHOTS = path.join(require('os').tmpdir(), 'anmates-ui-e2e-4');
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
  const phone = '+8411' + String(Date.now()).slice(-9) + Math.floor(Math.random() * 10);
  const r = await call('POST', '/auth/dev-login', null, { secret: SECRET, phone, name });
  return { token: r.data.access_token, refresh: r.data.refresh_token, id: r.data.user.id };
}

(async () => {
  require('fs').mkdirSync(SHOTS, { recursive: true });
  sql("DELETE FROM users WHERE email LIKE 'ui4+%@anmates.test' OR name LIKE 'UI4 %'");
  const email = `ui4+${Date.now()}@anmates.test`;
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
  const typeInto = async (loc, text) => {
    await loc.click(); await page.waitForTimeout(300);
    await page.keyboard.press('Control+A'); await page.keyboard.type(text, { delay: 15 });
    await page.waitForTimeout(300);
  };
  const clickText = async (re) => {
    const b = await page.getByText(re).first().boundingBox();
    await page.mouse.click(b.x + b.width / 2, b.y + b.height / 2);
    await page.waitForTimeout(1300);
  };
  const vis = (t, exact = false) => page.getByText(t, { exact }).first().isVisible().catch(() => false);

  try {
    // ── 1. Sign-up: consent is required, DOB picker, then the verify screen ──
    await page.goto(APP + '?v2screen=auth');
    await semantics();
    if (!(await vis('Tên mọi người sẽ thấy'))) await clickText(/Chưa có tài khoản/);
    await typeInto(page.getByRole('textbox', { name: /Tên mọi người sẽ thấy|Tên/ }).first(), 'UI4 Người Mới');
    await typeInto(page.getByRole('textbox', { name: /ban@email.com|Email/ }).first(), email);
    await typeInto(page.getByRole('textbox', { name: /Mật khẩu|Password|ký tự/ }).first(), 'supersecret-123');
    await page.getByRole('button', { name: /Ngày sinh/ }).first().click();
    await page.waitForTimeout(1200);
    await shot('01-dob-picker');
    await page.getByRole('button', { name: /^(OK|Đồng ý|CHỌN)$/i }).last().click();
    await page.waitForTimeout(1000);
    await page.getByRole('button', { name: /^Đăng ký$/ }).last().click(); // without consent
    await page.waitForTimeout(1200);
    await shot('02-no-consent');
    check('sign-up blocked without consent', await vis(/cần đồng ý Điều khoản/));
    check('DB: no account created without consent', sql(`SELECT count(*) FROM users WHERE email='${email}'`) === '0');
    // Reading the Terms must not wipe the form (it used to replace the screen): open, close, then submit.
    // The link spans have no semantics role; at this 402 px viewport "Điều khoản" sits ~242 px right of and
    // ~10 px above the checkbox's centre (see 02-no-consent.png).
    const cb = await page.getByRole('checkbox', { name: /Đồng ý Điều khoản/ }).first().boundingBox();
    await page.mouse.click(cb.x + cb.width / 2 + 242, cb.y + cb.height / 2 - 10);
    await page.waitForTimeout(1500);
    await shot('02b-terms-sheet');
    check('terms open as a sheet over the form', await vis('Điều khoản sử dụng') && await vis(/từ đủ 18 tuổi/));
    await page.getByRole('button', { name: /^Đóng$/ }).first().click();
    await page.waitForTimeout(1000);
    await shot('02c-after-close');
    check('form still filled after closing the terms', await vis('27/09/') || await vis(/\d\d\/\d\d\/\d{4}/));
    await page.getByRole('checkbox', { name: /Đồng ý Điều khoản/ }).first().click();
    await page.waitForTimeout(500);
    await page.getByRole('button', { name: /^Đăng ký$/ }).last().click();
    await page.waitForTimeout(4000);
    await shot('03-verify-screen');
    check('DB: account has birth date + consent', /^\d{4}-\d\d-\d\d\|t(rue)?$/.test(sql(`SELECT birth_date || '|' || (terms_accepted_at IS NOT NULL) FROM users WHERE email='${email}'`)),
      sql(`SELECT birth_date || '|' || (terms_accepted_at IS NOT NULL) FROM users WHERE email='${email}'`));
    check('form kept after reading terms (account created)', sql(`SELECT count(*) FROM users WHERE email='${email}'`) === '1');
    check('after sign-up: verify-email screen shown', await vis('Xác minh email'));
    check('DB: a code was requested automatically', sql(`SELECT count(*) FROM email_otps WHERE email='${email}'`) !== '0');

    // ── 2. Enter a wrong code, then the right one (planted: real codes are emailed) ──
    const hash = crypto.createHash('sha256').update('424242').digest('base64');
    sql(`UPDATE email_otps SET code_hash='${hash}' WHERE id=(SELECT id FROM email_otps WHERE email='${email}' ORDER BY created_at DESC LIMIT 1)`);
    const codeBox = page.getByRole('textbox').first();
    await typeInto(codeBox, '000000');
    await page.getByRole('button', { name: /^Xác minh$/ }).last().click().catch(() => clickText(/^Xác minh$/));
    await page.waitForTimeout(1500);
    check('wrong code → error shown', await vis(/Mã sai hoặc đã hết hạn/));
    await typeInto(codeBox, '424242');
    await page.getByRole('button', { name: /^Xác minh$/ }).last().click().catch(() => clickText(/^Xác minh$/));
    await page.waitForTimeout(2500);
    await shot('04-after-verify');
    check('DB: email verified via UI', sql(`SELECT email_verified_at IS NOT NULL FROM users WHERE email='${email}'`).startsWith('t'));

    // ── 3. Legal pages from Me ──
    await page.goto(APP + '?v2screen=home');
    await semantics();
    await clickText(/^Tôi$/);
    await page.waitForTimeout(1200);
    check('me: no verify banner once verified', !(await vis(/Xác minh email để bắt đầu/)));
    await page.getByText('Quyền riêng tư', { exact: true }).last().scrollIntoViewIfNeeded().catch(() => {});
    await clickText(/^Quyền riêng tư$/);
    await shot('05-privacy');
    check('privacy page opens with Decree 13 section', await vis('Chính sách quyền riêng tư') && await vis(/Nghị định 13\/2023/));
    await page.goto(APP + '?v2screen=terms');
    await semantics();
    await shot('06-terms');
    check('terms page renders 18+ rule', await vis(/từ đủ 18 tuổi/));

    // ── 4. Admin queue: suspend a reported account ──
    const admin = await devUser('UI4 Admin'), bad = await devUser('UI4 Kẻ Xấu'), rep = await devUser('UI4 Người Báo');
    sql(`UPDATE users SET is_admin=TRUE WHERE id='${admin.id}'`);
    await call('POST', '/reports', rep.token, { user_id: bad.id, reason: 'harassment', note: 'Nhắn tin khiếm nhã' });
    await page.goto(APP);
    await page.evaluate(([t, r, id]) => {
      localStorage.clear();
      localStorage.setItem('flutter.access_token', JSON.stringify(t));
      localStorage.setItem('flutter.refresh_token', JSON.stringify(r));
      localStorage.setItem('flutter.user_id', JSON.stringify(id));
    }, [admin.token, admin.refresh, admin.id]);
    await page.goto(APP + '?v2screen=home');
    await semantics();
    await clickText(/^Tôi$/);
    await page.waitForTimeout(1500);
    await page.getByText(/Quản trị báo cáo/).first().scrollIntoViewIfNeeded().catch(() => {});
    await clickText(/Quản trị báo cáo/);
    await page.waitForTimeout(1500);
    await shot('07-admin');
    check('admin queue lists the report', await vis('UI4 Kẻ Xấu') && await vis(/Nhắn tin khiếm nhã/));
    await clickText(/^Khoá tài khoản$/);
    await shot('08-admin-confirm');
    await page.getByRole('button', { name: /^Khoá$/ }).last().click();
    await page.waitForTimeout(1800);
    await shot('09-admin-after');
    check('DB: reported account suspended via UI', sql(`SELECT suspended_at IS NOT NULL FROM users WHERE id='${bad.id}'`).startsWith('t'));
    check('queue item removed', !(await vis(/Nhắn tin khiếm nhã/)));
  } catch (e) {
    await shot('ERROR');
    results.push('ERROR ' + e.message.split('\n')[0]);
  }
  results.push('page errors: ' + (errs.length ? errs.join(' | ') : 'none'));
  console.log(results.join('\n'));
  await browser.close();
})().catch((e) => { console.error('FAILED', e.message); process.exit(1); });
