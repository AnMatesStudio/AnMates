import puppeteer from '/tmp/node_modules/puppeteer/lib/esm/puppeteer/puppeteer.js';

const URL = 'http://127.0.0.1:54180';
const OUT = 'c:/AnM/AnMatesStudio/AnMates/.claude/shared-memory/screenshots/latest/';

const browser = await puppeteer.launch({
  executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe',
  headless: 'new',
  args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-gpu'],
});

async function snap(name, extraDelay = 0) {
  const page = await browser.newPage();
  await page.setViewport({ width: 390, height: 844, deviceScaleFactor: 2 });
  await page.goto(URL, { waitUntil: 'networkidle0', timeout: 30000 });
  // Wait for Flutter canvas to paint
  await page.waitForSelector('flt-glass-pane, canvas, flt-scene', { timeout: 15000 }).catch(() => {});
  await new Promise(r => setTimeout(r, 2500 + extraDelay));
  await page.screenshot({ path: OUT + name, type: 'png' });
  await page.close();
  console.log('saved', name);
}

// Step 1 (initial load)
await snap('step1.png');

// Click the "Tiếp tục →" button to advance pages
const page2 = await browser.newPage();
await page2.setViewport({ width: 390, height: 844, deviceScaleFactor: 2 });
await page2.goto(URL, { waitUntil: 'networkidle0', timeout: 30000 });
await page2.waitForSelector('flt-glass-pane, canvas, flt-scene', { timeout: 15000 }).catch(() => {});
await new Promise(r => setTimeout(r, 2500));

// Navigate to page 4 by clicking 3 times
for (let i = 0; i < 3; i++) {
  // Click bottom-right area where the button is (approx 310, 790 for 390×844 viewport)
  await page2.mouse.click(310, 790);
  await new Promise(r => setTimeout(r, 800));
}
await new Promise(r => setTimeout(r, 2000)); // let animations settle
await page2.screenshot({ path: OUT + 'step4.png', type: 'png' });
console.log('saved step4.png');
await page2.close();

await browser.close();
console.log('done');
