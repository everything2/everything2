#!/usr/bin/env node

/**
 * E2 Browser Debugging Tool
 *
 * Usage:
 *   node tools/browser-debug.js [command] [options]
 *
 * Commands:
 *   screenshot [url]           - Take a screenshot of the page
 *   console [url]              - Monitor console logs
 *   inspect [url] [selector]   - Inspect element and get properties
 *   check-nodelets [url]       - Check which nodelets are visible
 *   login [username] [pass]    - Login and take screenshot
 *
 * Examples:
 *   node tools/browser-debug.js screenshot http://localhost:9080
 *   node tools/browser-debug.js console http://localhost:9080
 *   node tools/browser-debug.js inspect http://localhost:9080 "#other_users"
 *   node tools/browser-debug.js check-nodelets http://localhost:9080
 *   node tools/browser-debug.js login root password
 */

const puppeteer = require('puppeteer');

const BASE_URL = process.env.E2_URL || 'http://localhost:9080';

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

async function loginAndScreenshot(username = 'root', password = 'blah') {
  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  const page = await browser.newPage();

  await page.setViewport({ width: 1280, height: 1024 });

  console.log(`Logging in as ${username}...`);
  await page.goto(BASE_URL, { waitUntil: 'networkidle2' });

  // Fill in login form
  await page.type('input[name="user"]', username);
  await page.type('input[name="passwd"]', password);
  await page.click('input[type="submit"]');

  // Wait for navigation
  await page.waitForNavigation({ waitUntil: 'networkidle2' });

  const filename = `/tmp/e2-logged-in-${username}-${Date.now()}.png`;
  await page.screenshot({ path: filename, fullPage: true });

  console.log(`Logged in screenshot saved to: ${filename}`);

  // Check what's on the page
  const pageInfo = await page.evaluate(() => {
    return {
      title: document.title,
      url: window.location.href,
      userNode: window.e2 ? window.e2.user : null,
      nodelets: window.e2 ? Object.keys(window.e2).filter(k => k.includes('nodelet') || k.includes('Data')) : []
    };
  });

  console.log('Page info:', JSON.stringify(pageInfo, null, 2));

  await browser.close();
  return filename;
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
        await loginAndScreenshot(arg1, arg2);
        break;

      default:
        console.log('Unknown command. Available commands:');
        console.log('  screenshot [url]           - Take a screenshot');
        console.log('  console [url]              - Monitor console logs');
        console.log('  inspect [url] [selector]   - Inspect element');
        console.log('  check-nodelets [url]       - Check nodelets');
        console.log('  login [username] [pass]    - Login and screenshot');
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
  loginAndScreenshot
};
