const puppeteer = require('puppeteer');

const BASE_URL = 'http://development.everything2.com:9080';

(async () => {
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage();
  await page.setViewport({ width: 375, height: 812, isMobile: true, hasTouch: true });
  await page.goto(BASE_URL, { waitUntil: 'networkidle0' });

  // Get header details
  const headerInfo = await page.evaluate(() => {
    const header = document.querySelector('#header');
    const innerHeader = header?.querySelector('header');
    const logo = document.querySelector('#e2logo');
    const searchform = document.querySelector('#searchform');
    const signInBtn = header?.querySelector('button');

    return {
      headerHTML: header?.innerHTML?.substring(0, 800),
      headerStyles: header ? window.getComputedStyle(header) : null,
      innerHeaderStyles: innerHeader ? {
        display: window.getComputedStyle(innerHeader).display,
        padding: window.getComputedStyle(innerHeader).padding,
        backgroundColor: window.getComputedStyle(innerHeader).backgroundColor,
        height: window.getComputedStyle(innerHeader).height
      } : null,
      logoText: logo?.textContent,
      logoStyles: logo ? {
        fontFamily: window.getComputedStyle(logo).fontFamily,
        fontSize: window.getComputedStyle(logo).fontSize,
        color: window.getComputedStyle(logo).color
      } : null,
      searchWidth: searchform ? window.getComputedStyle(searchform).width : null,
      signInText: signInBtn?.textContent
    };
  });

  console.log('Header info:', JSON.stringify(headerInfo, null, 2));

  // Take a cropped screenshot of just the header area
  const headerElement = await page.$('#header');
  if (headerElement) {
    await headerElement.screenshot({ path: '/tmp/mobile-header-only.png' });
    console.log('Header screenshot saved to /tmp/mobile-header-only.png');
  }

  await browser.close();
})();
