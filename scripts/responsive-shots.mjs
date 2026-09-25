#!/usr/bin/env node
// scripts/responsive-shots.mjs — screenshot every v2 screen at every viewport of
// the responsive test matrix (docs/plans/2026-09-25-responsive-mobile/README.md §3.3).
//
//   node scripts/responsive-shots.mjs [--build] [--screens home,swipe]
//        [--viewports se-safari,iphone15-safari] [--out screenshots/responsive/<label>]
//        [--web <dir>]
//
// --build      flutter build web --release --dart-define=V2_DEBUG_NAV=true first.
//              The define compiles in the `?v2screen=` / `?v2step=` deep link
//              (V2State._initialScreen); without it every URL opens onboarding.
// --screens    subset of screens (onb0…onb4, home, filters, …). Default: all.
// --viewports  subset of viewport ids. Default: all 14.
// --out        output dir, relative to the repo root. Default: screenshots/responsive/latest.
// --web        web build to serve. Default: anmates_flutter/build/web.
//
// Writes <out>/<viewport>/<screen>.png and <out>/index.html (a contact sheet).
// iPhone viewports run in WebKit, Android and landscape in Chromium. The
// text-scale variants of the test matrix are skipped: a browser has no
// equivalent the app would read.
//
// Playwright is not a dependency of this repo: it resolves from the global npm
// install (`npm i -g playwright`, 1.60 on the dev machine).

import { spawnSync } from 'node:child_process';
import { createReadStream, existsSync, mkdirSync, statSync, writeFileSync } from 'node:fs';
import { createServer } from 'node:http';
import { createRequire } from 'node:module';
import { homedir, platform } from 'node:os';
import { dirname, extname, join, normalize, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const repo = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const app = join(repo, 'anmates_flutter');

// ── Matrix ──────────────────────────────────────────────────────────────────

/** README §3.3. `engine` follows the platform the row stands for. */
const VIEWPORTS = [
  { id: 'floor-320', width: 320, height: 568, engine: 'webkit' },
  { id: 'fold-cover', width: 344, height: 882, engine: 'chromium' },
  { id: 'android-16x9', width: 360, height: 560, engine: 'chromium' },
  { id: 'android-hd', width: 360, height: 680, engine: 'chromium' },
  { id: 'se-safari', width: 375, height: 553, engine: 'webkit' },
  { id: 'se-app', width: 375, height: 667, engine: 'webkit' },
  { id: 'iphone14-safari', width: 390, height: 664, engine: 'webkit' },
  { id: 'iphone15-safari', width: 393, height: 668, engine: 'webkit' },
  { id: 'iphone15-app', width: 393, height: 852, engine: 'webkit' },
  { id: 'design-frame', width: 402, height: 874, engine: 'webkit' },
  { id: 'pixel', width: 412, height: 800, engine: 'chromium' },
  { id: 'promax-safari', width: 430, height: 750, engine: 'webkit' },
  { id: 'widest', width: 440, height: 956, engine: 'webkit' },
  { id: 'landscape', width: 844, height: 390, engine: 'chromium' },
];

/** Onboarding is one screen with five steps; every other V2Screen is one shot. */
const SCREENS = [
  ...[0, 1, 2, 3, 4].map((step) => ({ name: `onb${step}`, query: `v2screen=onb&v2step=${step}` })),
  ...['home', 'filters', 'detail', 'swipe', 'chat', 'bill', 'rate', 'me', 'trust', 'pay', 'local', 'allVenues']
    .map((name) => ({ name, query: `v2screen=${name}` })),
];

// ── Args ────────────────────────────────────────────────────────────────────

function parseArgs(argv) {
  const opts = { build: false, screens: null, viewports: null, out: 'screenshots/responsive/latest', web: null };
  for (let i = 0; i < argv.length; i++) {
    const [flag, inline] = argv[i].split(/=(.*)/s);
    const value = () => inline ?? argv[++i];
    switch (flag) {
      case '--build': opts.build = true; break;
      case '--screens': opts.screens = value().split(','); break;
      case '--viewports': opts.viewports = value().split(','); break;
      case '--out': opts.out = value(); break;
      case '--web': opts.web = value(); break;
      default:
        console.error(`Unknown argument: ${argv[i]}`);
        process.exit(2);
    }
  }
  return opts;
}

function pick(all, names, kind) {
  if (!names) return all;
  const byName = new Map(all.map((x) => [x.id ?? x.name, x]));
  const unknown = names.filter((n) => !byName.has(n));
  if (unknown.length) {
    console.error(`Unknown ${kind}: ${unknown.join(', ')}. Known: ${[...byName.keys()].join(', ')}`);
    process.exit(2);
  }
  return names.map((n) => byName.get(n));
}

// ── Flutter (same resolution order as run-flutter.mjs) ──────────────────────

function resolveFlutter() {
  if (process.env.FLUTTER_BIN && existsSync(process.env.FLUTTER_BIN)) return process.env.FLUTTER_BIN;
  const isWin = platform() === 'win32';
  const where = spawnSync(isWin ? 'where' : 'which', ['flutter'], { encoding: 'utf8' });
  const fromPath = where.status === 0 ? where.stdout.split(/\r?\n/).find(Boolean)?.trim() : null;
  if (fromPath) return fromPath;
  const exe = isWin ? 'flutter.bat' : 'flutter';
  const candidates = isWin
    ? [
        process.env.LOCALAPPDATA && join(process.env.LOCALAPPDATA, 'flutter', 'bin', exe),
        join(homedir(), 'flutter', 'bin', exe),
        'C:\\flutter\\bin\\flutter.bat',
        'C:\\src\\flutter\\bin\\flutter.bat',
        'C:\\dev\\flutter\\bin\\flutter.bat',
      ]
    : [join(homedir(), 'flutter', 'bin', exe), '/opt/homebrew/bin/flutter', '/usr/local/bin/flutter'];
  return candidates.filter(Boolean).find(existsSync) ?? null;
}

function build() {
  const flutter = resolveFlutter();
  if (!flutter) {
    console.error("Couldn't find Flutter. Set FLUTTER_BIN or add flutter to PATH.");
    process.exit(127);
  }
  console.log(`> ${flutter} build web --release --dart-define=V2_DEBUG_NAV=true`);
  const r = spawnSync(flutter, ['build', 'web', '--release', '--dart-define=V2_DEBUG_NAV=true'], {
    cwd: app,
    stdio: 'inherit',
    shell: platform() === 'win32',
  });
  if (r.status !== 0) process.exit(r.status ?? 1);
}

// ── Static server ───────────────────────────────────────────────────────────

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json',
  '.wasm': 'application/wasm',
  '.css': 'text/css',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.webp': 'image/webp',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
};

function serve(root) {
  return new Promise((resolveServer) => {
    const server = createServer((req, res) => {
      const path = decodeURIComponent(new URL(req.url, 'http://x').pathname);
      let file = normalize(join(root, path));
      if (!file.startsWith(root + sep) && file !== root) {
        res.writeHead(403).end();
        return;
      }
      if (!existsSync(file) || statSync(file).isDirectory()) file = join(root, 'index.html');
      res.writeHead(200, {
        'content-type': MIME[extname(file).toLowerCase()] ?? 'application/octet-stream',
        'cache-control': 'no-store',
      });
      createReadStream(file).pipe(res);
    });
    // Port 0: the OS picks a free one.
    server.listen(0, '127.0.0.1', () => resolveServer(server));
  });
}

// ── Playwright ──────────────────────────────────────────────────────────────

function loadPlaywright() {
  const require = createRequire(import.meta.url);
  const candidates = [
    'playwright',
    process.env.APPDATA && join(process.env.APPDATA, 'npm', 'node_modules', 'playwright'),
    join(homedir(), 'AppData', 'Roaming', 'npm', 'node_modules', 'playwright'),
  ].filter(Boolean);
  for (const c of candidates) {
    try {
      const m = require(c);
      if (m?.chromium && m?.webkit) return m;
    } catch {
      // try the next one
    }
  }
  console.error('Playwright not found. Install it globally: npm i -g playwright && npx playwright install webkit chromium');
  process.exit(70);
}

/**
 * Resolves once no request has been in flight for [idleMs], or after [capMs]
 * (API calls to an unreachable backend may never settle). Unlike Playwright's
 * `networkidle` load state, this can be awaited again later in the page's life.
 */
function quiet(page, idleMs = 500, capMs = 15_000) {
  return new Promise((done) => {
    const start = Date.now();
    const tick = () => {
      if (page.__inflight === 0 && Date.now() - page.__lastActivity >= idleMs) return done();
      if (Date.now() - start >= capMs) return done();
      setTimeout(tick, 100);
    };
    tick();
  });
}

function trackRequests(page) {
  page.__inflight = 0;
  page.__lastActivity = Date.now();
  const bump = (d) => () => {
    page.__inflight += d;
    page.__lastActivity = Date.now();
  };
  page.on('request', bump(1));
  page.on('requestfinished', bump(-1));
  page.on('requestfailed', bump(-1));
}

async function shoot(context, base, screen, file) {
  const page = await context.newPage();
  trackRequests(page);
  try {
    await page.goto(`${base}/?${screen.query}`, { waitUntil: 'load', timeout: 60_000 });
    await page.waitForSelector('flutter-view, flt-glass-pane', { state: 'attached', timeout: 60_000 });
    // google_fonts and the engine's fallback fonts (for glyphs such as →) are
    // fetched after the first frame. A fixed wait alone raced them: shots came
    // out in the fallback font, with tofu boxes or a missing arrow. The
    // fallback request only starts once a frame hits the missing glyph, so
    // wait for quiet, let the entry animations run, then wait for quiet again.
    await quiet(page);
    await page.waitForTimeout(1500);
    await quiet(page);
    await page.screenshot({ path: file });
    return null;
  } catch (e) {
    return e.message.split('\n')[0];
  } finally {
    await page.close();
  }
}

/** Runs [tasks] (functions returning promises) with at most [n] in flight. */
async function pool(tasks, n) {
  const results = [];
  let next = 0;
  await Promise.all(
    Array.from({ length: Math.min(n, tasks.length) }, async () => {
      while (next < tasks.length) {
        const i = next++;
        results[i] = await tasks[i]();
      }
    }),
  );
  return results;
}

// ── Contact sheet ───────────────────────────────────────────────────────────

function contactSheet(out, label, screens, viewports, failures) {
  const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
  const head = viewports
    .map((v) => `<th>${esc(v.id)}<br><small>${v.width}×${v.height} · ${v.engine}</small></th>`)
    .join('');
  const rows = screens
    .map((s) => {
      const cells = viewports
        .map((v) => {
          const key = `${v.id}/${s.name}`;
          // Screenshots are at deviceScaleFactor 2; one third of that is 2/3 of the viewport.
          const w = Math.round((v.width * 2) / 3);
          const h = Math.round((v.height * 2) / 3);
          return failures.has(key)
            ? `<td class="fail" style="width:${w}px">FAILED<br><small>${esc(failures.get(key))}</small></td>`
            : `<td><a href="${esc(key)}.png"><img src="${esc(key)}.png" width="${w}" height="${h}" loading="lazy" alt="${esc(key)}"></a></td>`;
        })
        .join('');
      return `<tr><th class="row">${esc(s.name)}</th>${cells}</tr>`;
    })
    .join('\n');

  writeFileSync(
    join(out, 'index.html'),
    `<!doctype html>
<meta charset="utf-8">
<title>Responsive shots · ${esc(label)}</title>
<style>
  body { font: 13px system-ui, sans-serif; margin: 16px; background: #f4f2ef; color: #222; }
  table { border-collapse: collapse; }
  th, td { border: 1px solid #ccc; padding: 4px; vertical-align: top; text-align: center; background: #fff; }
  thead th { position: sticky; top: 0; z-index: 1; }
  th.row { position: sticky; left: 0; writing-mode: vertical-rl; transform: rotate(180deg); }
  img { display: block; }
  td.fail { background: #fde8e8; color: #a00; }
</style>
<h1>${esc(label)}</h1>
<p>${screens.length} screens × ${viewports.length} viewports · generated ${new Date().toISOString()}</p>
<table>
<thead><tr><th></th>${head}</tr></thead>
<tbody>
${rows}
</tbody>
</table>
`,
  );
}

// ── Main ────────────────────────────────────────────────────────────────────

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  const screens = pick(SCREENS, opts.screens, 'screens');
  const viewports = pick(VIEWPORTS, opts.viewports, 'viewports');
  const out = resolve(repo, opts.out);
  const web = resolve(opts.web ?? join(app, 'build', 'web'));

  if (opts.build) build();
  if (!existsSync(join(web, 'index.html'))) {
    console.error(`No web build at ${web}. Run with --build.`);
    process.exit(1);
  }

  const server = await serve(web);
  const base = `http://127.0.0.1:${server.address().port}`;
  console.log(`Serving ${web} at ${base}`);
  const pw = loadPlaywright();
  const failures = new Map();

  try {
    for (const engine of ['webkit', 'chromium']) {
      const rows = viewports.filter((v) => v.engine === engine);
      if (!rows.length) continue;
      const browser = await pw[engine].launch({ headless: true });
      try {
        for (const v of rows) {
          mkdirSync(join(out, v.id), { recursive: true });
          const context = await browser.newContext({
            viewport: { width: v.width, height: v.height },
            deviceScaleFactor: 2,
            isMobile: true,
            hasTouch: true,
          });
          const results = await pool(
            screens.map((s) => () => shoot(context, base, s, join(out, v.id, `${s.name}.png`))),
            4,
          );
          await context.close();
          results.forEach((err, i) => {
            if (err) failures.set(`${v.id}/${screens[i].name}`, err);
          });
          const bad = results.filter(Boolean).length;
          console.log(`${v.id.padEnd(16)} ${engine.padEnd(8)} ${screens.length - bad}/${screens.length} shots`);
        }
      } finally {
        await browser.close();
      }
    }
  } finally {
    server.close();
  }

  contactSheet(out, relative(repo, out), screens, viewports, failures);
  console.log(`Contact sheet: ${join(out, 'index.html')}`);
  if (failures.size) {
    console.error(`${failures.size} shot(s) failed:`);
    for (const [k, e] of failures) console.error(`  ${k}: ${e}`);
    process.exit(1);
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
