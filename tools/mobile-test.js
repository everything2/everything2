const puppeteer = require('puppeteer');

const BASE_URL = 'http://development.everything2.com:9080';
const TEST_USERS = {
  'e2e_user': { password: 'test123' },
  'e2e_admin': { password: 'test123' }
};

async function loginAndGetCookies(browser, username) {
  const user = TEST_USERS[username];
  if (!user) throw new Error('Unknown user: ' + username);

  const page = await browser.newPage();
  await page.goto(BASE_URL, { waitUntil: 'networkidle0' });

  // Login by filling form
  await page.evaluate(async (username, password) => {
    const form = document.createElement('form');
    form.method = 'POST';
    form.action = '/';
    form.innerHTML = `
      <input name="op" value="login">
      <input name="node" value="login">
      <input name="user" value="${username}">
      <input name="passwd" value="${password}">
    `;
    document.body.appendChild(form);
    form.submit();
  }, username, user.password);

  await page.waitForNavigation({ waitUntil: 'networkidle0' });

  const cookies = await page.cookies();
  await page.close();
  return cookies;
}

(async () => {
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  // Test 1: Guest mobile view
  console.log('=== Testing Guest Mobile View ===');
  const guestPage = await browser.newPage();
  await guestPage.setViewport({ width: 375, height: 812, isMobile: true, hasTouch: true });
  await guestPage.goto(BASE_URL, { waitUntil: 'networkidle0' });
  await guestPage.screenshot({ path: '/tmp/mobile-guest.png', fullPage: true });

  const guestLogo = await guestPage.evaluate(() => {
    const e2logo = document.querySelector('#e2logo');
    return e2logo ? e2logo.textContent : 'No logo found';
  });
  console.log('Guest logo:', guestLogo);

  const guestNav = await guestPage.evaluate(() => {
    const nav = document.querySelector('nav');
    if (!nav) return 'No nav found';
    const buttons = nav.querySelectorAll('button, a');
    return Array.from(buttons).map(b => b.textContent.trim()).join(', ');
  });
  console.log('Guest nav items:', guestNav);

  const guestSidebar = await guestPage.evaluate(() => {
    const sidebar = document.querySelector('#sidebar');
    if (!sidebar) return 'No sidebar';
    return window.getComputedStyle(sidebar).display;
  });
  console.log('Guest sidebar display:', guestSidebar);
  await guestPage.close();

  // Test 2: Logged-in mobile view
  console.log('\n=== Testing Logged-in Mobile View ===');
  try {
    const cookies = await loginAndGetCookies(browser, 'e2e_user');
    console.log('Got login cookies');

    const userPage = await browser.newPage();
    await userPage.setCookie(...cookies);
    await userPage.setViewport({ width: 375, height: 812, isMobile: true, hasTouch: true });
    await userPage.goto(BASE_URL, { waitUntil: 'networkidle0' });
    await userPage.screenshot({ path: '/tmp/mobile-loggedin.png', fullPage: true });

    const userLogo = await userPage.evaluate(() => {
      const e2logo = document.querySelector('#e2logo');
      return e2logo ? e2logo.textContent : 'No logo found';
    });
    console.log('User logo:', userLogo);

    const userNav = await userPage.evaluate(() => {
      const nav = document.querySelector('nav');
      if (!nav) return 'No nav found';
      const buttons = nav.querySelectorAll('button, a');
      return Array.from(buttons).map(b => b.textContent.trim()).join(', ');
    });
    console.log('User nav items:', userNav);

    // Check for user avatar in header
    const headerUserSection = await userPage.evaluate(() => {
      const header = document.querySelector('#header header');
      if (!header) return 'No header';
      const userLink = header.querySelector('a[href*="/user/"]');
      if (userLink) return 'Has user avatar link: ' + userLink.getAttribute('href');
      const signIn = header.querySelector('button');
      if (signIn) return 'Has Sign In button: ' + signIn.textContent;
      return 'Neither found';
    });
    console.log('Header user section:', headerUserSection);

    const userSidebar = await userPage.evaluate(() => {
      const sidebar = document.querySelector('#sidebar');
      if (!sidebar) return 'No sidebar';
      return window.getComputedStyle(sidebar).display;
    });
    console.log('User sidebar display:', userSidebar);

    await userPage.close();
  } catch (err) {
    console.log('Login test failed:', err.message);
  }

  // Test 3: Guest front page specific checks
  console.log('\n=== Testing Guest Front Page Layout ===');
  const gfpPage = await browser.newPage();
  await gfpPage.setViewport({ width: 375, height: 812, isMobile: true, hasTouch: true });
  await gfpPage.goto(BASE_URL, { waitUntil: 'networkidle0' });

  // Check for problematic layout issues
  const layoutInfo = await gfpPage.evaluate(() => {
    const wrapper = document.querySelector('#wrapper');
    const mainbody = document.querySelector('#mainbody');
    const sidebar = document.querySelector('#sidebar');
    const body = document.body;

    return {
      bodyPaddingBottom: window.getComputedStyle(body).paddingBottom,
      wrapperWidth: wrapper ? window.getComputedStyle(wrapper).width : 'N/A',
      mainbodyWidth: mainbody ? window.getComputedStyle(mainbody).width : 'N/A',
      sidebarDisplay: sidebar ? window.getComputedStyle(sidebar).display : 'N/A',
      viewportWidth: window.innerWidth
    };
  });
  console.log('Layout info:', layoutInfo);

  // Check ad space
  const adsInfo = await gfpPage.evaluate(() => {
    const adDivs = document.querySelectorAll('[id*="google"], [class*="ad-"]');
    return Array.from(adDivs).map(el => {
      const style = window.getComputedStyle(el);
      return {
        id: el.id || el.className,
        display: style.display,
        height: style.height
      };
    });
  });
  console.log('Ad-related elements:', adsInfo);

  await gfpPage.close();
  await browser.close();
  console.log('\nScreenshots saved to /tmp/mobile-guest.png and /tmp/mobile-loggedin.png');
})();
