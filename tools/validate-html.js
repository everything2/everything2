#!/usr/bin/env node
/**
 * HTML5 Validation Script for E2 React Components
 *
 * Validates rendered HTML from multiple pages for common HTML5 issues:
 * - Deprecated elements (center, font, big, etc.)
 * - Invalid nesting (div inside p, block inside inline)
 * - Missing required attributes (alt on img, etc.)
 * - Duplicate IDs
 * - Invalid attributes for HTML5
 *
 * Usage:
 *   node tools/validate-html.js [--fix-report] [--verbose]
 */

const puppeteer = require('puppeteer');

// Pages to validate (add more as needed)
const PAGES_TO_CHECK = [
  { url: '/', name: 'Front Page (guest)', user: null },
  { url: '/title/Welcome%20to%20Everything', name: 'Welcome (logged in)', user: 'e2e_admin' },
  { url: '/title/Sign%20Up', name: 'Sign Up', user: null },
  { url: '/title/Display%20Categories', name: 'Display Categories', user: null },
  { url: '/user/Cool%20Man%20Eddie', name: 'User Profile (with image)', user: null },
  { url: '/user/e2e_admin', name: 'Own Profile', user: 'e2e_admin' },
  { url: '/title/Settings', name: 'Settings', user: 'e2e_admin' },
  { url: '/title/Drafts', name: 'Drafts/Editor', user: 'e2e_admin' },
  { url: '/title/Cool%20Archive', name: 'Cool Archive', user: null },
  { url: '/title/New%20Writeups', name: 'New Writeups', user: null },
  { url: '/node/2000528', name: 'E2node Display', user: null },
  { url: '/title/Everything%20User%20Search', name: 'User Search', user: null },
  { url: '/title/Findings', name: 'Findings (no results)', user: null },
  { url: '/title/Writeups%20by%20Type', name: 'Writeups by Type', user: null },
  { url: '/title/Random%20Nodes', name: 'Random Nodes', user: null },
];

// Test user credentials
const TEST_USERS = {
  'e2e_admin': { password: 'test123' },
  'e2e_user': { password: 'test123' },
};

// Deprecated HTML elements (not valid in HTML5 strict)
const DEPRECATED_ELEMENTS = [
  'acronym', 'applet', 'basefont', 'bgsound', 'big', 'blink', 'center',
  'dir', 'font', 'frame', 'frameset', 'isindex', 'keygen', 'listing',
  'marquee', 'menuitem', 'multicol', 'nextid', 'nobr', 'noembed',
  'noframes', 'plaintext', 'spacer', 'strike', 'tt', 'xmp'
];

// Elements that cannot contain block-level elements
const INLINE_ONLY_PARENTS = ['a', 'abbr', 'b', 'bdo', 'cite', 'code', 'dfn',
  'em', 'i', 'kbd', 'label', 'q', 's', 'samp', 'small', 'span', 'strong',
  'sub', 'sup', 'u', 'var'];

// Block-level elements
const BLOCK_ELEMENTS = ['address', 'article', 'aside', 'blockquote', 'canvas',
  'dd', 'div', 'dl', 'dt', 'fieldset', 'figcaption', 'figure', 'footer',
  'form', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'header', 'hr', 'li', 'main',
  'nav', 'noscript', 'ol', 'p', 'pre', 'section', 'table', 'tfoot', 'ul', 'video'];

const BASE_URL = process.env.BASE_URL || 'http://localhost:9080';

async function login(page, username) {
  const creds = TEST_USERS[username];
  if (!creds) {
    console.error(`Unknown test user: ${username}`);
    return false;
  }

  try {
    await page.goto(`${BASE_URL}/`, { waitUntil: 'networkidle0', timeout: 30000 });

    // Use the login API directly
    const response = await page.evaluate(async (user, pass) => {
      const res = await fetch('/api/sessions/create', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'same-origin',
        body: JSON.stringify({ username: user, passwd: pass })
      });
      return { ok: res.ok, status: res.status };
    }, username, creds.password);

    return response.ok;
  } catch (err) {
    console.error(`Login failed for ${username}:`, err.message);
    return false;
  }
}

async function validatePage(page, url, name) {
  const issues = [];
  const fullUrl = `${BASE_URL}${url}`;

  try {
    await page.goto(fullUrl, { waitUntil: 'networkidle0', timeout: 30000 });

    // Wait for React to render
    await new Promise(resolve => setTimeout(resolve, 1000));

    // Run validation in browser context
    const pageIssues = await page.evaluate((deprecatedElements, inlineParents, blockElements) => {
      const issues = [];

      // 1. Check for deprecated elements
      deprecatedElements.forEach(tag => {
        const elements = document.querySelectorAll(tag);
        if (elements.length > 0) {
          issues.push({
            type: 'deprecated',
            severity: 'warning',
            message: `Deprecated <${tag}> element found (${elements.length} instance(s))`,
            count: elements.length,
            locations: Array.from(elements).slice(0, 3).map(el => {
              const parent = el.parentElement;
              return parent ? `inside <${parent.tagName.toLowerCase()}>` : 'at root';
            })
          });
        }
      });

      // 2. Check for duplicate IDs
      const allIds = {};
      document.querySelectorAll('[id]').forEach(el => {
        const id = el.id;
        if (allIds[id]) {
          allIds[id].count++;
          allIds[id].tags.push(el.tagName.toLowerCase());
        } else {
          allIds[id] = { count: 1, tags: [el.tagName.toLowerCase()] };
        }
      });
      Object.entries(allIds).forEach(([id, info]) => {
        if (info.count > 1) {
          issues.push({
            type: 'duplicate-id',
            severity: 'error',
            message: `Duplicate ID "${id}" found ${info.count} times`,
            tags: info.tags
          });
        }
      });

      // 3. Check for images without alt attribute
      const imgsWithoutAlt = document.querySelectorAll('img:not([alt])');
      if (imgsWithoutAlt.length > 0) {
        issues.push({
          type: 'missing-alt',
          severity: 'warning',
          message: `Images without alt attribute: ${imgsWithoutAlt.length}`,
          srcs: Array.from(imgsWithoutAlt).slice(0, 3).map(img => img.src.substring(0, 50))
        });
      }

      // 4. Check for block elements inside inline elements (common React mistake)
      inlineParents.forEach(parent => {
        document.querySelectorAll(parent).forEach(el => {
          blockElements.forEach(block => {
            const nested = el.querySelectorAll(`:scope > ${block}`);
            if (nested.length > 0) {
              issues.push({
                type: 'invalid-nesting',
                severity: 'error',
                message: `Block element <${block}> nested inside inline <${parent}>`,
                context: el.outerHTML.substring(0, 100)
              });
            }
          });
        });
      });

      // 5. Check for div/block inside <p> (very common mistake)
      document.querySelectorAll('p').forEach(p => {
        blockElements.forEach(block => {
          if (p.querySelector(block)) {
            issues.push({
              type: 'invalid-nesting',
              severity: 'error',
              message: `<${block}> found inside <p> - invalid HTML5`,
              context: p.innerHTML.substring(0, 80)
            });
          }
        });
      });

      // 6. Check for invalid button nesting (buttons can't contain interactive elements)
      document.querySelectorAll('button a, button button, a button, a a').forEach(el => {
        issues.push({
          type: 'invalid-nesting',
          severity: 'error',
          message: `Interactive element nested inside another interactive element`,
          context: el.outerHTML.substring(0, 100)
        });
      });

      // 7. Check for form elements outside forms (warning only)
      const formInputsOutside = document.querySelectorAll('input:not(form input), select:not(form select), textarea:not(form textarea)');
      // This is actually often OK, so just note it

      // 8. Check for tables with deprecated attributes
      document.querySelectorAll('table[cellpadding], table[cellspacing], table[border], table[bgcolor], table[align]').forEach(table => {
        issues.push({
          type: 'deprecated-attr',
          severity: 'warning',
          message: 'Table uses deprecated attributes (cellpadding, cellspacing, border, bgcolor, or align)',
          context: table.outerHTML.substring(0, 80)
        });
      });

      // 9. Check for inline style with deprecated properties
      // (This would require parsing style attributes, skip for now)

      // 10. Check for empty links
      document.querySelectorAll('a:not([href]), a[href=""], a[href="#"]').forEach(a => {
        if (!a.getAttribute('name') && !a.id) { // Skip anchor targets
          issues.push({
            type: 'empty-link',
            severity: 'warning',
            message: 'Link without meaningful href',
            text: a.textContent?.substring(0, 30) || '(empty)'
          });
        }
      });

      return issues;
    }, DEPRECATED_ELEMENTS, INLINE_ONLY_PARENTS, BLOCK_ELEMENTS);

    return { name, url, issues: pageIssues, error: null };

  } catch (err) {
    return { name, url, issues: [], error: err.message };
  }
}

async function main() {
  const verbose = process.argv.includes('--verbose');
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const results = [];
  let currentUser = null;
  let page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 1024 });

  console.log('\n=== E2 HTML5 Validation Report ===\n');
  console.log(`Base URL: ${BASE_URL}`);
  console.log(`Checking ${PAGES_TO_CHECK.length} pages...\n`);

  for (const pageInfo of PAGES_TO_CHECK) {
    // Handle login if needed
    if (pageInfo.user !== currentUser) {
      if (pageInfo.user) {
        process.stdout.write(`  Logging in as ${pageInfo.user}... `);
        const success = await login(page, pageInfo.user);
        if (success) {
          console.log('OK');
          currentUser = pageInfo.user;
        } else {
          console.log('FAILED');
          continue;
        }
      } else if (currentUser) {
        // Need to log out - just create new page
        await page.close();
        page = await browser.newPage();
        await page.setViewport({ width: 1280, height: 1024 });
        currentUser = null;
      }
    }

    process.stdout.write(`  Checking: ${pageInfo.name}... `);
    const result = await validatePage(page, pageInfo.url, pageInfo.name);
    results.push(result);

    if (result.error) {
      console.log(`ERROR: ${result.error}`);
    } else if (result.issues.length === 0) {
      console.log('OK');
    } else {
      const errors = result.issues.filter(i => i.severity === 'error').length;
      const warnings = result.issues.filter(i => i.severity === 'warning').length;
      console.log(`${errors} errors, ${warnings} warnings`);
    }
  }

  await browser.close();

  // Summary
  console.log('\n=== Summary ===\n');

  const pagesWithIssues = results.filter(r => r.issues.length > 0);
  const totalErrors = results.reduce((sum, r) => sum + r.issues.filter(i => i.severity === 'error').length, 0);
  const totalWarnings = results.reduce((sum, r) => sum + r.issues.filter(i => i.severity === 'warning').length, 0);

  console.log(`Pages checked: ${results.length}`);
  console.log(`Pages with issues: ${pagesWithIssues.length}`);
  console.log(`Total errors: ${totalErrors}`);
  console.log(`Total warnings: ${totalWarnings}`);

  if (pagesWithIssues.length > 0) {
    console.log('\n=== Detailed Issues ===\n');

    for (const result of pagesWithIssues) {
      console.log(`\n${result.name} (${result.url}):`);

      for (const issue of result.issues) {
        const icon = issue.severity === 'error' ? '  [ERROR]' : '  [WARN] ';
        console.log(`${icon} ${issue.message}`);

        if (verbose && issue.context) {
          console.log(`         Context: ${issue.context}...`);
        }
        if (verbose && issue.locations) {
          console.log(`         Locations: ${issue.locations.join(', ')}`);
        }
      }
    }
  }

  // Aggregate common issues across all pages
  const issueTypes = {};
  for (const result of results) {
    for (const issue of result.issues) {
      const key = `${issue.type}:${issue.message.split(':')[0]}`;
      if (!issueTypes[key]) {
        issueTypes[key] = { count: 0, pages: [], severity: issue.severity };
      }
      issueTypes[key].count++;
      issueTypes[key].pages.push(result.name);
    }
  }

  if (Object.keys(issueTypes).length > 0) {
    console.log('\n=== Most Common Issues ===\n');
    const sorted = Object.entries(issueTypes).sort((a, b) => b[1].count - a[1].count);
    for (const [key, info] of sorted.slice(0, 10)) {
      const [type, msg] = key.split(':');
      console.log(`  ${info.count}x [${info.severity.toUpperCase()}] ${type}: ${msg}`);
      if (verbose) {
        console.log(`     Pages: ${info.pages.join(', ')}`);
      }
    }
  }

  console.log('\n');
  process.exit(totalErrors > 0 ? 1 : 0);
}

main().catch(err => {
  console.error('Validation failed:', err);
  process.exit(1);
});
