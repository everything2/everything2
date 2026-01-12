const puppeteer = require('puppeteer');

const BASE_URL = 'http://development.everything2.com:9080';

const wait = (ms) => new Promise(resolve => setTimeout(resolve, ms));

(async () => {
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  console.log('=== Mobile Interaction Tests ===\n');

  // Test 1: Auth modal from bottom nav
  console.log('Test 1: Sign In button opens Auth Modal');
  const page1 = await browser.newPage();
  await page1.setViewport({ width: 375, height: 812, isMobile: true, hasTouch: true });
  await page1.goto(BASE_URL, { waitUntil: 'networkidle0' });

  // Find and click Sign In in bottom nav
  const signInClicked = await page1.evaluate(() => {
    const nav = document.querySelector('nav');
    if (!nav) return 'No nav found';
    const buttons = nav.querySelectorAll('button');
    for (const btn of buttons) {
      if (btn.textContent.includes('Sign In')) {
        btn.click();
        return 'Clicked Sign In';
      }
    }
    return 'Sign In button not found';
  });
  console.log('  ' + signInClicked);

  await wait(500);

  // Check if auth modal appeared
  const authModalVisible = await page1.evaluate(() => {
    // Look for modal overlay
    const overlays = document.querySelectorAll('div[style*="position: fixed"]');
    for (const overlay of overlays) {
      const style = window.getComputedStyle(overlay);
      if (style.backgroundColor.includes('rgba') && style.zIndex > 1000) {
        // Check if it has login form
        const hasLoginTab = overlay.textContent.includes('Log In');
        const hasSignupTab = overlay.textContent.includes('Sign Up');
        if (hasLoginTab && hasSignupTab) {
          return 'Auth modal is visible with Login/Signup tabs';
        }
      }
    }
    return 'Auth modal not found';
  });
  console.log('  ' + authModalVisible);

  await page1.screenshot({ path: '/tmp/mobile-auth-modal.png', fullPage: false });
  console.log('  Screenshot: /tmp/mobile-auth-modal.png');

  // Close auth modal by clicking overlay
  await page1.evaluate(() => {
    const overlays = document.querySelectorAll('div[style*="position: fixed"]');
    for (const overlay of overlays) {
      if (overlay.style.zIndex > 1000) {
        overlay.click();
        break;
      }
    }
  });
  await wait(300);
  await page1.close();

  // Test 2: Discover menu
  console.log('\nTest 2: Discover button opens menu');
  const page2 = await browser.newPage();
  await page2.setViewport({ width: 375, height: 812, isMobile: true, hasTouch: true });
  await page2.goto(BASE_URL, { waitUntil: 'networkidle0' });

  // Find and click Discover in bottom nav
  const discoverClicked = await page2.evaluate(() => {
    const nav = document.querySelector('nav');
    if (!nav) return 'No nav found';
    const buttons = nav.querySelectorAll('button');
    for (const btn of buttons) {
      if (btn.textContent.includes('Discover')) {
        btn.click();
        return 'Clicked Discover';
      }
    }
    return 'Discover button not found';
  });
  console.log('  ' + discoverClicked);

  await wait(500);

  // Check if discover menu appeared
  const discoverMenuVisible = await page2.evaluate(() => {
    // Look for bottom sheet overlay
    const overlays = document.querySelectorAll('div[style*="position: fixed"]');
    for (const overlay of overlays) {
      if (overlay.textContent.includes('New Writeups') &&
          overlay.textContent.includes('Random Node')) {
        return 'Discover menu is visible with navigation links';
      }
    }
    return 'Discover menu not found';
  });
  console.log('  ' + discoverMenuVisible);

  await page2.screenshot({ path: '/tmp/mobile-discover-menu.png', fullPage: false });
  console.log('  Screenshot: /tmp/mobile-discover-menu.png');
  await page2.close();

  // Test 3: Auth modal from header Sign In button
  console.log('\nTest 3: Header Sign In button opens Auth Modal');
  const page3 = await browser.newPage();
  await page3.setViewport({ width: 375, height: 812, isMobile: true, hasTouch: true });
  await page3.goto(BASE_URL, { waitUntil: 'networkidle0' });

  // Find and click Sign In in header
  const headerSignInClicked = await page3.evaluate(() => {
    const header = document.querySelector('#header');
    if (!header) return 'No header found';
    const buttons = header.querySelectorAll('button');
    for (const btn of buttons) {
      if (btn.textContent.includes('Sign In')) {
        btn.click();
        return 'Clicked header Sign In';
      }
    }
    return 'Header Sign In button not found';
  });
  console.log('  ' + headerSignInClicked);

  await wait(500);

  // Check if auth modal appeared
  const headerAuthModalVisible = await page3.evaluate(() => {
    const overlays = document.querySelectorAll('div[style*="position: fixed"]');
    for (const overlay of overlays) {
      const style = window.getComputedStyle(overlay);
      if (style.backgroundColor.includes('rgba') && style.zIndex > 1000) {
        const hasLoginTab = overlay.textContent.includes('Log In');
        const hasSignupTab = overlay.textContent.includes('Sign Up');
        if (hasLoginTab && hasSignupTab) {
          return 'Auth modal is visible';
        }
      }
    }
    return 'Auth modal not found';
  });
  console.log('  ' + headerAuthModalVisible);

  await page3.screenshot({ path: '/tmp/mobile-header-auth.png', fullPage: false });
  console.log('  Screenshot: /tmp/mobile-header-auth.png');
  await page3.close();

  // Test 4: Check ad space is not huge
  console.log('\nTest 4: Ad space check');
  const page4 = await browser.newPage();
  await page4.setViewport({ width: 375, height: 812, isMobile: true, hasTouch: true });
  await page4.goto(BASE_URL, { waitUntil: 'networkidle0' });

  const adInfo = await page4.evaluate(() => {
    const headerAds = document.querySelector('.headerads');
    if (!headerAds) return 'No headerads div found';
    const rect = headerAds.getBoundingClientRect();
    return `Ad container: height=${rect.height}px, width=${rect.width}px`;
  });
  console.log('  ' + adInfo);
  await page4.close();

  await browser.close();
  console.log('\n=== All tests completed ===');
})();
