const puppeteer = require('C:/Users/Admin/AppData/Local/Temp/node_modules/puppeteer');

const URL  = 'http://127.0.0.1:54180';
const OUT  = 'C:/AnM/AnMatesStudio/AnMates/.claude/shared-memory/screenshots/latest/';

(async () => {
  const browser = await puppeteer.launch({
    executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe',
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-gpu'],
  });

  async function snap(name, clicks) {
    const page = await browser.newPage();
    await page.setViewport({ width: 390, height: 844, deviceScaleFactor: 2 });
    await page.goto(URL, { waitUntil: 'networkidle0', timeout: 30000 });
    // Wait for Flutter to boot (canvas or shadow-root)
    await new Promise(r => setTimeout(r, 4000));
    // Click through pages
    for (let i = 0; i < clicks; i++) {
      await page.mouse.click(310, 790);
      await new Promise(r => setTimeout(r, 700));
    }
    await new Promise(r => setTimeout(r, 2500)); // let animations settle
    await page.screenshot({ path: OUT + name, type: 'png' });
    console.log('saved', name);
    await page.close();
  }

  await snap('step1.png', 0);
  await snap('step4.png', 3);

  await browser.close();
  console.log('done');
})();
