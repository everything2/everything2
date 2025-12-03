#!/usr/bin/env node

/**
 * E2 Browser Debugging Tool
 *
 * Usage:
 *   node tools/browser-debug.js [command] [options]
 *
 * Commands:
 *   screenshot [url]           - Take a screenshot of the page (guest user)
 *   console [url]              - Monitor console logs (guest user)
 *   inspect [url] [selector]   - Inspect element and get properties (guest user)
 *   check-nodelets [url]       - Check which nodelets are visible (guest user)
 *   login [username]           - Login as test user and take screenshot
 *   fetch [username] [url]     - Fetch URL as authenticated user, output page info
 *   screenshot-as [username] [url] - Take screenshot as authenticated user
 *   html [username] [url]      - Fetch URL as authenticated user, output raw HTML
 *   post [username] [url] [json] - POST JSON to API endpoint as authenticated user
 *   delete [username] [url]     - DELETE request to API endpoint as authenticated user
 *
 * Available Test Users (from tools/seeds.pl):
 *   root              - Admin (gods + e2gods), password: blah
 *   genericdev        - Developer (edev), password: blah
 *   genericeditor     - Content Editor, password: blah
 *   genericchanop     - Channel Operator (chanops), password: blah
 *   c_e               - Message forwarding test user, password: blah
 *   normaluser1-30    - Regular users, password: blah
 *   user with space   - Username with space, password: blah
 *
 * E2E Test Users (for automated testing):
 *   e2e_admin         - Admin (gods), password: test123
 *   e2e_editor        - Content Editor, password: test123
 *   e2e_developer     - Developer (edev), password: test123
 *   e2e_chanop        - Channel Operator (chanops), password: test123
 *   e2e_user          - Regular user, password: test123
 *   e2e user space    - Username with space, password: test123
 *
 * Examples:
 *   node tools/browser-debug.js screenshot http://localhost:9080
 *   node tools/browser-debug.js console http://localhost:9080
 *   node tools/browser-debug.js inspect http://localhost:9080 "#other_users"
 *   node tools/browser-debug.js check-nodelets http://localhost:9080
 *   node tools/browser-debug.js login root
 *   node tools/browser-debug.js fetch e2e_admin http://localhost:9080/title/Settings
 *   node tools/browser-debug.js fetch genericdev http://localhost:9080
 *   node tools/browser-debug.js screenshot-as e2e_editor http://localhost:9080/title/Wheel+of+Surprise
 */

const puppeteer = require('puppeteer');

// Default base URL - can be overridden with E2_URL environment variable
// For reCAPTCHA testing in dev, use: E2_URL=http://development.everything2.com:9080
const BASE_URL = process.env.E2_URL || 'http://localhost:9080';
const DEV_URL = 'http://development.everything2.com:9080';

/**
 * Get the base URL to use for authentication
 * If the target URL is for development.everything2.com, use that for auth
 * Otherwise use BASE_URL
 */
function getBaseUrlForAuth(targetUrl) {
  if (targetUrl && targetUrl.includes('development.everything2.com')) {
    return DEV_URL;
  }
  return BASE_URL;
}

// Test user credentials from tools/seeds.pl
const TEST_USERS = {
  // Seeds.pl users (password: blah)
  'root': { password: 'blah', role: 'Admin (gods + e2gods)' },
  'genericdev': { password: 'blah', role: 'Developer (edev)' },
  'genericeditor': { password: 'blah', role: 'Content Editor' },
  'genericchanop': { password: 'blah', role: 'Channel Operator (chanops)' },
  'c_e': { password: 'blah', role: 'Message forwarding test user' },
  'user with space': { password: 'blah', role: 'Username with space test' },

  // E2E test users (password: test123)
  'e2e_admin': { password: 'test123', role: 'E2E Admin (gods)' },
  'e2e_editor': { password: 'test123', role: 'E2E Content Editor' },
  'e2e_developer': { password: 'test123', role: 'E2E Developer (edev)' },
  'e2e_chanop': { password: 'test123', role: 'E2E Channel Operator' },
  'e2e_user': { password: 'test123', role: 'E2E Regular User' },
  'e2e user space': { password: 'test123', role: 'E2E Username with space' },

  // Normaluser 1-30 (password: blah)
  ...Array.from({length: 30}, (_, i) => ({
    [`normaluser${i + 1}`]: { password: 'blah', role: `Regular user ${i + 1}` }
  })).reduce((acc, curr) => ({...acc, ...curr}), {})
};

async function screenshot(url = BASE_URL) {
  const browser = await puppeteer.launch({ headless: true });
  const page = await browser.newPage();

  await page.setViewport({ width: 1280, height: 1024 });

  console.log(`Navigating to ${url}...`);
  await page.goto(url, { waitUntil: 'networkidle2' });

  const filename = `/tmp/e2-screenshot-${Date.now()}.png`;
  await page.screenshot({ path: filename, fullPage: true });

  console.log(`Screenshot saved to: ${filename}`);

  await browser.close();
  return filename;
}

async function monitorConsole(url = BASE_URL) {
  const browser = await puppeteer.launch({ headless: true });
  const page = await browser.newPage();

  // Monitor console messages
  page.on('console', msg => {
    const type = msg.type();
    const text = msg.text();
    console.log(`[BROWSER ${type.toUpperCase()}]: ${text}`);
  });

  // Monitor page errors
  page.on('pageerror', error => {
    console.log(`[BROWSER ERROR]: ${error.message}`);
  });

  console.log(`Monitoring console for ${url}...`);
  await page.goto(url, { waitUntil: 'networkidle2' });

  // Wait a bit to capture any delayed logs
  await page.waitForTimeout(2000);

  await browser.close();
}

async function inspectElement(url = BASE_URL, selector) {
  const browser = await puppeteer.launch({ headless: true });
  const page = await browser.newPage();

  await page.goto(url, { waitUntil: 'networkidle2' });

  const element = await page.$(selector);

  if (!element) {
    console.log(`Element not found: ${selector}`);
    await browser.close();
    return;
  }

  // Get element properties
  const properties = await page.evaluate(sel => {
    const el = document.querySelector(sel);
    if (!el) return null;

    return {
      tagName: el.tagName,
      id: el.id,
      className: el.className,
      innerHTML: el.innerHTML.substring(0, 500), // First 500 chars
      textContent: el.textContent.substring(0, 200),
      style: {
        display: window.getComputedStyle(el).display,
        visibility: window.getComputedStyle(el).visibility,
        height: window.getComputedStyle(el).height
      },
      children: el.children.length,
      attributes: Array.from(el.attributes).map(attr => ({
        name: attr.name,
        value: attr.value
      }))
    };
  }, selector);

  console.log('Element properties:', JSON.stringify(properties, null, 2));

  await browser.close();
  return properties;
}

async function checkNodelets(url = BASE_URL) {
  const browser = await puppeteer.launch({ headless: true });
  const page = await browser.newPage();

  await page.goto(url, { waitUntil: 'networkidle2' });

  const nodelets = await page.evaluate(() => {
    const containers = document.querySelectorAll('.nodeletContainer, [class*="nodelet"]');

    return Array.from(containers).map(el => {
      const title = el.querySelector('h3, h4, .nodeletTitle');
      return {
        id: el.id,
        className: el.className,
        title: title ? title.textContent.trim() : 'Unknown',
        visible: window.getComputedStyle(el).display !== 'none',
        collapsed: el.classList.contains('collapsed') ||
                   el.getAttribute('aria-expanded') === 'false'
      };
    });
  });

  console.log('Found nodelets:', JSON.stringify(nodelets, null, 2));

  await browser.close();
  return nodelets;
}

/**
 * Helper function to validate username and return user info
 */
function validateUser(username) {
  if (!username) {
    console.error('Username required');
    console.error('\nAvailable test users:');
    Object.entries(TEST_USERS).forEach(([user, info]) => {
      console.error(`  ${user.padEnd(20)} - ${info.role}`);
    });
    throw new Error('Username required');
  }

  const userInfo = TEST_USERS[username];
  if (!userInfo) {
    console.error(`Unknown user: ${username}`);
    console.error('\nAvailable test users:');
    Object.entries(TEST_USERS).forEach(([user, info]) => {
      console.error(`  ${user.padEnd(20)} - ${info.role}`);
    });
    throw new Error(`User '${username}' not found in TEST_USERS`);
  }

  return userInfo;
}

/**
 * Helper function to create authenticated browser session
 * @param {string} username - The username to log in as
 * @param {string} targetUrl - Optional target URL (used to determine which base URL to use for auth)
 */
async function createAuthenticatedSession(username, targetUrl = null) {
  const userInfo = validateUser(username);
  const password = userInfo.password;

  // Determine which base URL to use based on target URL
  const authBaseUrl = getBaseUrlForAuth(targetUrl);

  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 1024 });

  console.log(`Logging in as ${username} (${userInfo.role}) via ${authBaseUrl}...`);

  // ALWAYS log in against the root page to ensure Sign In nodelet is present
  // This handles fullpage layouts (chatterlight) that don't have the standard sidebar
  await page.goto(authBaseUrl, { waitUntil: 'domcontentloaded', timeout: 15000 });

  // Wait for Sign In nodelet to load, then expand if collapsed
  await page.waitForSelector('#signin_user', { timeout: 5000 });

  // Check if nodelet is collapsed and expand it
  const signInHeader = await page.evaluateHandle(() => {
    // Find the h2 containing "Sign In" text
    const headers = Array.from(document.querySelectorAll('h2'));
    return headers.find(h => h.textContent.includes('Sign In'));
  });

  if (signInHeader) {
    const isCollapsed = await page.evaluate(el =>
      el && (el.className.includes('is-closed') || el.getAttribute('aria-expanded') === 'false'),
      signInHeader
    );
    if (isCollapsed) {
      await signInHeader.click();
      await new Promise(resolve => setTimeout(resolve, 300)); // Wait for expand animation
    }
  }

  // Fill in login form (use IDs from SignIn nodelet)
  await page.type('#signin_user', username);
  await page.type('#signin_passwd', password);

  // Click submit button
  await page.click('input[type="submit"]');

  // Wait for JavaScript redirect to complete
  // E2 login returns HTML with JS redirect, not HTTP 302
  await page.waitForNavigation({ waitUntil: 'networkidle0', timeout: 10000 });

  // Wait for authentication to complete by checking for user in window.e2
  // Don't wait for #epicenter - it doesn't exist in fullpage layouts
  await page.waitForFunction(() => {
    return window.e2 && window.e2.user && !window.e2.user.guest;
  }, { timeout: 5000 });

  return { browser, page, userInfo };
}

/**
 * Helper function to extract page information
 */
async function extractPageInfo(page) {
  return await page.evaluate(() => {
    return {
      title: document.title,
      url: window.location.href,
      userNode: window.e2 ? window.e2.user : null,
      contentData: window.e2 ? window.e2.contentData : null,
      nodelets: window.e2 ? Object.keys(window.e2).filter(k => k.includes('nodelet') || k.includes('Data')) : [],
      hasReact: !!document.querySelector('#e2-react-root'),
      bodyText: document.body ? document.body.innerText.substring(0, 500) : null
    };
  });
}

async function loginAndScreenshot(username) {
  const { browser, page, userInfo } = await createAuthenticatedSession(username);

  const filename = `/tmp/e2-logged-in-${username.replace(/\s+/g, '_')}-${Date.now()}.png`;
  await page.screenshot({ path: filename, fullPage: true });

  console.log(`Logged in screenshot saved to: ${filename}`);

  const pageInfo = await extractPageInfo(page);
  console.log('Page info:', JSON.stringify(pageInfo, null, 2));

  await browser.close();
  return filename;
}

async function fetchAsUser(username, url = BASE_URL) {
  const { browser, page, userInfo } = await createAuthenticatedSession(username, url);

  console.log(`Navigating to ${url}...`);
  await page.goto(url, { waitUntil: 'networkidle0', timeout: 15000 });

  // Wait for React lazy-loaded components to finish loading
  // The "Loading..." text is React Suspense's fallback
  await page.waitForFunction(() => {
    const pageRoot = document.querySelector('#e2-react-page-root');
    // Wait until the loading placeholder is gone
    return !pageRoot || !pageRoot.textContent.includes('Loading...');
  }, { timeout: 10000 }).catch(() => {
    console.log('Note: React components may still be loading');
  });

  const pageInfo = await extractPageInfo(page);
  console.log('\n=== Page Info ===');
  console.log(JSON.stringify(pageInfo, null, 2));

  await browser.close();
  return pageInfo;
}

async function screenshotAsUser(username, url = BASE_URL) {
  const { browser, page, userInfo } = await createAuthenticatedSession(username, url);

  console.log(`Navigating to ${url}...`);
  await page.goto(url, { waitUntil: 'networkidle0', timeout: 15000 });

  // Wait for React lazy-loaded components to finish loading
  await page.waitForFunction(() => {
    const pageRoot = document.querySelector('#e2-react-page-root');
    return !pageRoot || !pageRoot.textContent.includes('Loading...');
  }, { timeout: 10000 }).catch(() => {
    console.log('Note: React components may still be loading');
  });

  const filename = `/tmp/e2-${username.replace(/\s+/g, '_')}-${Date.now()}.png`;
  await page.screenshot({ path: filename, fullPage: true });

  console.log(`Screenshot saved to: ${filename}`);

  const pageInfo = await extractPageInfo(page);
  console.log('\n=== Page Info ===');
  console.log(JSON.stringify(pageInfo, null, 2));

  await browser.close();
  return filename;
}

async function getHtmlAsUser(username, url = BASE_URL) {
  const { browser, page, userInfo } = await createAuthenticatedSession(username, url);

  // Navigate to target URL
  await page.goto(url, { waitUntil: 'networkidle0', timeout: 15000 });

  // Wait for React lazy-loaded components to finish loading
  await page.waitForFunction(() => {
    const pageRoot = document.querySelector('#e2-react-page-root');
    return !pageRoot || !pageRoot.textContent.includes('Loading...');
  }, { timeout: 10000 }).catch(() => {});

  // Get full HTML content
  const html = await page.content();

  await browser.close();

  // Output raw HTML to stdout (no prefixes, just like curl)
  console.log(html);

  return html;
}

/**
 * Fetch URL as guest (no authentication)
 */
async function fetchAsGuest(url = BASE_URL) {
  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 1024 });

  console.log(`Navigating to ${url} as guest...`);
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 10000 });

  const pageInfo = await extractPageInfo(page);
  console.log('\n=== Page Info (Guest) ===');
  console.log(JSON.stringify(pageInfo, null, 2));

  await browser.close();
  return pageInfo;
}

/**
 * POST JSON to an API endpoint as authenticated user
 */
async function postAsUser(username, url, jsonData) {
  return await httpRequestAsUser(username, url, jsonData, 'POST');
}

/**
 * PUT JSON to an API endpoint as authenticated user
 */
async function putAsUser(username, url, jsonData) {
  return await httpRequestAsUser(username, url, jsonData, 'PUT');
}

/**
 * DELETE request to an API endpoint as authenticated user
 */
async function deleteAsUser(username, url) {
  return await httpRequestAsUser(username, url, null, 'DELETE');
}

/**
 * Generic HTTP request (POST/PUT/DELETE) to an API endpoint as authenticated user
 */
async function httpRequestAsUser(username, url, jsonData, method) {
  const { browser, page, userInfo } = await createAuthenticatedSession(username, url);

  console.log(`${method} request to ${url}...`);

  // Parse JSON data if it's a string
  let dataObj = jsonData;
  if (jsonData && typeof jsonData === 'string') {
    try {
      dataObj = JSON.parse(jsonData);
    } catch (e) {
      console.error('Invalid JSON:', e.message);
      await browser.close();
      throw e;
    }
  }

  // Navigate to a base page to ensure we have a proper context
  // This is important for fetch to work with credentials
  const baseUrl = getBaseUrlForAuth(url);
  if (!page.url().startsWith(baseUrl)) {
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded', timeout: 10000 });
  }

  // Make the HTTP request from within the browser context
  const result = await page.evaluate(async (apiUrl, data, httpMethod) => {
    try {
      const fetchOptions = {
        method: httpMethod,
        credentials: 'same-origin'
      };

      // Only add body for methods that support it
      if (data && httpMethod !== 'GET' && httpMethod !== 'DELETE') {
        fetchOptions.headers = { 'Content-Type': 'application/json' };
        fetchOptions.body = JSON.stringify(data);
      }

      const response = await fetch(apiUrl, fetchOptions);
      const text = await response.text();
      let parsedData;
      try {
        parsedData = JSON.parse(text);
      } catch (e) {
        parsedData = text;
      }
      return {
        status: response.status,
        statusText: response.statusText,
        data: parsedData
      };
    } catch (err) {
      return { error: err.message };
    }
  }, url, dataObj, method);

  console.log(`\n=== ${method} Result ===`);
  console.log(JSON.stringify(result, null, 2));

  await browser.close();
  return result;
}

/**
 * Get HTML for URL as guest (no authentication)
 */
async function getHtmlAsGuest(url = BASE_URL) {
  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  const page = await browser.newPage();

  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 10000 });

  const html = await page.content();

  await browser.close();

  // Output raw HTML to stdout (no prefixes, just like curl)
  console.log(html);

  return html;
}

// Main command handler
async function main() {
  const command = process.argv[2];
  const arg1 = process.argv[3];
  const arg2 = process.argv[4];

  try {
    switch(command) {
      case 'screenshot':
        await screenshot(arg1);
        break;

      case 'console':
        await monitorConsole(arg1);
        break;

      case 'inspect':
        if (!arg2) {
          console.error('Usage: inspect [url] [selector]');
          process.exit(1);
        }
        await inspectElement(arg1, arg2);
        break;

      case 'check-nodelets':
        await checkNodelets(arg1);
        break;

      case 'login':
        await loginAndScreenshot(arg1);
        break;

      case 'fetch':
        if (!arg1) {
          console.error('Usage: fetch [username] [url]');
          console.error('Example: fetch e2e_admin http://localhost:9080/title/Settings');
          process.exit(1);
        }
        await fetchAsUser(arg1, arg2);
        break;

      case 'screenshot-as':
        if (!arg1) {
          console.error('Usage: screenshot-as [username] [url]');
          console.error('Example: screenshot-as e2e_developer http://localhost:9080');
          process.exit(1);
        }
        await screenshotAsUser(arg1, arg2);
        break;

      case 'html':
        if (!arg1) {
          console.error('Usage: html [username] [url]');
          console.error('Example: html e2e_admin http://localhost:9080/title/Superbless');
          process.exit(1);
        }
        await getHtmlAsUser(arg1, arg2);
        break;

      case 'post':
        if (!arg1 || !arg2) {
          console.error('Usage: post [username] [url] [json]');
          console.error('Example: post e2e_admin http://localhost:9080/api/drafts \'{"title":"Test","doctext":"content"}\'');
          process.exit(1);
        }
        // JSON data is the 5th argument (index 5)
        const jsonDataPost = process.argv[5];
        if (!jsonDataPost) {
          console.error('JSON data required');
          process.exit(1);
        }
        await postAsUser(arg1, arg2, jsonDataPost);
        break;

      case 'put':
        if (!arg1 || !arg2) {
          console.error('Usage: put [username] [url] [json]');
          console.error('Example: put e2e_admin http://localhost:9080/api/drafts/123 \'{"title":"Test","doctext":"content"}\'');
          process.exit(1);
        }
        // JSON data is the 5th argument (index 5)
        const jsonDataPut = process.argv[5];
        if (!jsonDataPut) {
          console.error('JSON data required');
          process.exit(1);
        }
        await putAsUser(arg1, arg2, jsonDataPut);
        break;

      case 'delete':
        if (!arg1 || !arg2) {
          console.error('Usage: delete [username] [url]');
          console.error('Example: delete e2e_admin http://localhost:9080/api/userinteractions/123/action/delete');
          process.exit(1);
        }
        await deleteAsUser(arg1, arg2);
        break;

      case 'guest-fetch':
        await fetchAsGuest(arg1);
        break;

      case 'guest-html':
        await getHtmlAsGuest(arg1);
        break;

      default:
        console.log('Unknown command. Available commands:');
        console.log('  screenshot [url]                - Take a screenshot (guest)');
        console.log('  console [url]                   - Monitor console logs (guest)');
        console.log('  inspect [url] [selector]        - Inspect element (guest)');
        console.log('  check-nodelets [url]            - Check nodelets (guest)');
        console.log('  guest-fetch [url]               - Fetch URL as guest, show page info');
        console.log('  guest-html [url]                - Fetch URL as guest, output raw HTML');
        console.log('  login [username]                - Login as user and screenshot');
        console.log('  fetch [username] [url]          - Fetch URL as user, show page info');
        console.log('  screenshot-as [username] [url]  - Take screenshot as user');
        console.log('  html [username] [url]           - Fetch URL as user, output raw HTML');
        console.log('  post [username] [url] [json]    - POST JSON to API as user');
        console.log('  delete [username] [url]         - DELETE request to API as user');
        console.log('\nRun "node tools/browser-debug.js login" to see available test users');
        process.exit(1);
    }
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}

module.exports = {
  screenshot,
  monitorConsole,
  inspectElement,
  checkNodelets,
  loginAndScreenshot,
  fetchAsUser,
  screenshotAsUser,
  getHtmlAsUser,
  postAsUser,
  deleteAsUser,
  fetchAsGuest,
  getHtmlAsGuest
};
