# E2E Testing Strategy for Everything2

## Overview

This document outlines a strategy for automated end-to-end (E2E) testing to catch nuanced UI issues that unit tests miss: layout shifts, animations, cross-browser rendering, real user interactions, and integration bugs.

**Goal**: Automated headless browser testing that runs after smoke + React tests pass, verifying the complete user experience.

## Tool Recommendation: Playwright

**Recommended Tool**: **Playwright** (over Puppeteer or Cypress)

**Why Playwright:**
- ✅ **Multi-browser support**: Chromium, Firefox, WebKit (Safari) out of the box
- ✅ **Auto-wait**: Smart waiting for elements, no manual sleeps
- ✅ **Network interception**: Mock API responses, test offline mode
- ✅ **Screenshots/videos**: Capture failures automatically
- ✅ **Parallel execution**: Fast test runs
- ✅ **TypeScript support**: Better IDE integration
- ✅ **Active development**: Microsoft-backed, modern API
- ✅ **Docker-friendly**: Headless mode perfect for CI/CD

**Comparison**:
| Feature | Playwright | Puppeteer | Cypress |
|---------|-----------|-----------|---------|
| Multi-browser | ✅ Chrome, Firefox, Safari | ❌ Chrome only | ⚠️ Limited Safari |
| Speed | ⚡ Very fast | ⚡ Very fast | 🐌 Slower |
| Network mocking | ✅ Built-in | ⚠️ Manual | ✅ Built-in |
| Docker/CI | ✅ Excellent | ✅ Excellent | ⚠️ Complex |
| Learning curve | ⚡ Easy | ⚡ Easy | ⚡ Easy |
| Documentation | 📚 Excellent | 📚 Good | 📚 Excellent |

## Implementation Plan

### Phase 1: Setup (1-2 hours)

```bash
# Install Playwright
npm install --save-dev @playwright/test
npx playwright install  # Downloads browsers

# Create test directory structure
mkdir -p tests/e2e
touch tests/e2e/chatterbox.spec.js
touch tests/e2e/messages.spec.js
touch tests/e2e/wheel.spec.js
```

**playwright.config.js**:
```javascript
module.exports = {
  testDir: './tests/e2e',
  timeout: 30000,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : 3,

  use: {
    baseURL: 'http://localhost:9080',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    trace: 'retain-on-failure',
  },

  projects: [
    { name: 'chromium', use: { browserName: 'chromium' } },
    { name: 'firefox', use: { browserName: 'firefox' } },
    { name: 'webkit', use: { browserName: 'webkit' } },
  ],
}
```

### Phase 2: Core Test Scenarios

#### Example 1: Chatterbox Message Sending

**tests/e2e/chatterbox.spec.js**:
```javascript
const { test, expect } = require('@playwright/test')

test.describe('Chatterbox', () => {
  test.beforeEach(async ({ page }) => {
    // Login
    await page.goto('/login')
    await page.fill('[name="user"]', 'root')
    await page.fill('[name="passwd"]', 'blah')
    await page.click('[type="submit"]')
    await page.waitForURL('/')
  })

  test('sends message without layout shift', async ({ page }) => {
    // Measure initial layout
    const initialHeight = await page.locator('#chatterbox').boundingBox()

    // Type and send message
    await page.fill('#message', 'test message')
    await page.click('#message_send')

    // Wait for success message to appear
    await expect(page.locator('text=Message sent successfully')).toBeVisible()

    // Verify no layout shift occurred
    const afterHeight = await page.locator('#chatterbox').boundingBox()
    expect(afterHeight.height).toBeCloseTo(initialHeight.height, 5) // Within 5px
  })

  test('success message fades out', async ({ page }) => {
    // Send message
    await page.fill('#message', 'test fade')
    await page.click('#message_send')

    // Success message appears
    const successMsg = page.locator('text=Message sent successfully')
    await expect(successMsg).toBeVisible()

    // Starts with opacity 1
    let opacity = await successMsg.evaluate(el =>
      window.getComputedStyle(el).opacity
    )
    expect(parseFloat(opacity)).toBeCloseTo(1, 1)

    // Wait for fade to start (3 seconds display time)
    await page.waitForTimeout(3000)

    // Check opacity is decreasing (fading)
    opacity = await successMsg.evaluate(el =>
      window.getComputedStyle(el).opacity
    )
    expect(parseFloat(opacity)).toBeLessThan(1)

    // Message disappears after fade (300ms transition)
    await expect(successMsg).not.toBeVisible({ timeout: 500 })
  })

  test('error message covers chat commands link', async ({ page }) => {
    // Trigger error (send empty message somehow, or mock API failure)
    await page.route('/api/chatter/create', route =>
      route.fulfill({
        status: 400,
        body: JSON.stringify({ success: false, error: 'Test error' })
      })
    )

    await page.fill('#message', 'test error')
    await page.click('#message_send')

    // Error message appears
    const errorMsg = page.locator('text=Test error')
    await expect(errorMsg).toBeVisible()

    // Get positions
    const errorBox = await errorMsg.boundingBox()
    const commandsLink = await page.locator('text=Chat Commands').boundingBox()

    // Error should overlay commands (higher z-index, same area)
    expect(errorBox.y).toBeLessThanOrEqual(commandsLink.y)
  })

  test('special commands render correctly', async ({ page }) => {
    // Test /me command
    await page.fill('#message', '/me waves')
    await page.click('#message_send')

    // Verify italic formatting
    await expect(page.locator('em:has-text("root waves")')).toBeVisible()

    // Test /roll command
    await page.fill('#message', '/roll 1d6')
    await page.click('#message_send')

    // Verify small-caps formatting
    await expect(page.locator('text=/roll.*1d6/')).toHaveCSS(
      'font-variant', 'small-caps'
    )
  })
})
```

#### Example 2: Mini Messages

**tests/e2e/messages.spec.js**:
```javascript
const { test, expect } = require('@playwright/test')

test.describe('Mini Messages', () => {
  test('loads initial messages on page load', async ({ page }) => {
    // Login as user with messages
    await page.goto('/login')
    await page.fill('[name="user"]', 'root')
    await page.fill('[name="passwd"]', 'blah')
    await page.click('[type="submit"]')
    await page.waitForURL('/')

    // Check if mini messages section exists
    const miniMessages = page.locator('#chatterbox_messages')

    // If user has no Messages nodelet, mini messages should show
    if (await miniMessages.isVisible()) {
      // Verify messages loaded WITHOUT an API call
      // (Check network tab for no /api/messages/ call on page load)
      const apiCalls = []
      page.on('request', req => {
        if (req.url().includes('/api/messages/')) {
          apiCalls.push(req.url())
        }
      })

      await page.reload()

      // Should have messages data from initial page load (no API call)
      await expect(miniMessages).toBeVisible()
      expect(apiCalls.length).toBe(0) // No API calls on initial load
    }
  })
})
```

#### Example 3: Wheel of Surprise

**tests/e2e/wheel.spec.js**:
```javascript
const { test, expect } = require('@playwright/test')

test.describe('Wheel of Surprise', () => {
  test('displays spin result', async ({ page }) => {
    // Login
    await page.goto('/login')
    await page.fill('[name="user"]', 'root')
    await page.fill('[name="passwd"]', 'blah')
    await page.click('[type="submit"]')

    // Navigate to wheel
    await page.goto('/title/Wheel+of+Surprise')

    // Click spin button
    await page.click('button:has-text("Spin the Wheel")')

    // Verify result appears
    await expect(page.locator('text=/You won|nothing|GP|egg|cool/i'))
      .toBeVisible({ timeout: 5000 })

    // Verify GP deducted
    const gpBefore = await page.locator('text=/\\d+ GP/').textContent()
    // ... verify GP changed
  })

  test('admin can sanctify themselves', async ({ page }) => {
    // Login as admin
    await page.goto('/login')
    await page.fill('[name="user"]', 'root')
    await page.fill('[name="passwd"]', 'blah')
    await page.click('[type="submit"]')

    // Navigate to sanctify page
    await page.goto('/title/Sanctify+user')

    // Type own username
    await page.fill('[name="give_to"]', 'root')
    await page.click('input[name="give_GP"]')

    // Should succeed (not show "cannot sanctify yourself" error)
    await expect(page.locator('text=cannot sanctify yourself'))
      .not.toBeVisible()
    await expect(page.locator('text=has been given 10 GP'))
      .toBeVisible()
  })
})
```

### Phase 3: Integration with Test Suite

**docker/devbuild.sh** - Add E2E tests after smoke/unit tests:

```bash
# ... existing tests ...

=========================================
Running E2E tests...
=========================================
npx playwright test

if [ $? -ne 0 ]; then
  echo "E2E tests failed!"
  exit 1
fi
```

**Or create separate script**: `./tools/e2e-test.sh`:

```bash
#!/bin/bash
set -e

echo "=== E2E Tests ==="

# Ensure application is running
if ! curl -sf http://localhost:9080 > /dev/null; then
  echo "ERROR: Application not running at localhost:9080"
  exit 1
fi

# Run Playwright tests
npx playwright test

echo "✅ E2E tests passed!"
```

### Phase 4: Visual Regression Testing (Optional)

Playwright can capture screenshots and compare for visual regressions:

```javascript
test('chatterbox layout matches baseline', async ({ page }) => {
  await page.goto('/')

  // Login
  await page.fill('[name="user"]', 'root')
  await page.fill('[name="passwd"]', 'blah')
  await page.click('[type="submit"]')

  // Capture screenshot of chatterbox
  const chatterbox = page.locator('#chatterbox')
  await expect(chatterbox).toHaveScreenshot('chatterbox-baseline.png', {
    maxDiffPixels: 100  // Allow minor rendering differences
  })
})
```

## Test Organization

```
tests/
  e2e/
    fixtures/
      auth.js              # Reusable login helper
      test-users.js        # Test user credentials
    chatterbox.spec.js     # Chatterbox functionality
    messages.spec.js       # Mini messages + Messages nodelet
    wheel.spec.js          # Wheel of Surprise
    sanctify.spec.js       # Sanctify user
    silver-trinkets.spec.js # Silver trinkets
    navigation.spec.js     # Cross-page navigation
    responsive.spec.js     # Mobile/desktop layouts
```

## Fixtures & Helpers

**tests/e2e/fixtures/auth.js**:
```javascript
async function loginAsRoot(page) {
  await page.goto('/login')
  await page.fill('[name="user"]', 'root')
  await page.fill('[name="passwd"]', 'blah')
  await page.click('[type="submit"]')
  await page.waitForURL('/')
}

async function loginAsGuest(page) {
  // Just visit homepage without logging in
  await page.goto('/')
}

module.exports = { loginAsRoot, loginAsGuest }
```

## CI/CD Integration

**GitHub Actions** (`.github/workflows/test.yml`):

```yaml
name: E2E Tests

on: [push, pull_request]

jobs:
  e2e:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Setup Node
        uses: actions/setup-node@v3
        with:
          node-version: 20

      - name: Install dependencies
        run: npm ci

      - name: Install Playwright browsers
        run: npx playwright install --with-deps

      - name: Start E2 dev environment
        run: ./docker/devbuild.sh

      - name: Run E2E tests
        run: npx playwright test

      - name: Upload test results
        if: failure()
        uses: actions/upload-artifact@v3
        with:
          name: playwright-results
          path: test-results/
```

## Performance Benchmarks

Track performance metrics during E2E tests:

```javascript
test('page load performance', async ({ page }) => {
  await page.goto('/', { waitUntil: 'networkidle' })

  const metrics = await page.evaluate(() => {
    const nav = performance.getEntriesByType('navigation')[0]
    return {
      domContentLoaded: nav.domContentLoadedEventEnd - nav.domContentLoadedEventStart,
      loadComplete: nav.loadEventEnd - nav.loadEventStart,
      totalTime: nav.loadEventEnd - nav.fetchStart,
    }
  })

  expect(metrics.totalTime).toBeLessThan(3000) // Page loads in < 3s
})
```

## Debugging Failed Tests

```bash
# Run tests in headed mode (see browser)
npx playwright test --headed

# Run specific test
npx playwright test tests/e2e/chatterbox.spec.js

# Debug mode (opens inspector)
npx playwright test --debug

# Generate test report
npx playwright show-report

# Run with trace (detailed timeline)
npx playwright test --trace on
```

## Coverage Gaps This Addresses

E2E tests catch issues that unit tests miss:

| Issue Type | Unit Test | E2E Test |
|------------|-----------|----------|
| Layout shift from error messages | ❌ Can't detect | ✅ Measures DOM changes |
| Fade-out animations | ❌ Can't verify CSS transitions | ✅ Checks opacity over time |
| API response format | ⚠️ Tests mock responses | ✅ Tests real API |
| Cross-browser rendering | ❌ JSDOM only | ✅ Chrome, Firefox, Safari |
| Real user interactions | ❌ Simulated events | ✅ Real clicks, typing |
| Initial page load data | ❌ Passes props | ✅ Tests full request cycle |
| Network failures | ⚠️ Manual mocking | ✅ Route interception |
| Cookie/session handling | ❌ Can't test | ✅ Real browser cookies |

## Next Steps

1. **Install Playwright**: `npm install --save-dev @playwright/test`
2. **Create config**: Copy playwright.config.js above
3. **Write first test**: Start with chatterbox.spec.js
4. **Run locally**: `npx playwright test --headed`
5. **Integrate into devbuild.sh**: Add after smoke tests
6. **Document in CLAUDE.md**: Add to testing section
7. **CI/CD**: Add to GitHub Actions workflow

## Estimated Timeline

- **Phase 1 (Setup)**: 1-2 hours
- **Phase 2 (Core tests)**: 4-6 hours (10-15 tests)
- **Phase 3 (Integration)**: 1 hour
- **Phase 4 (Visual regression)**: 2-3 hours (optional)

**Total**: ~8-12 hours for comprehensive E2E coverage

## Resources

- [Playwright Documentation](https://playwright.dev)
- [Best Practices](https://playwright.dev/docs/best-practices)
- [API Reference](https://playwright.dev/docs/api/class-playwright)
- [CI/CD Setup](https://playwright.dev/docs/ci)

---

**Benefits Summary**:
- ✅ Catch nuanced UI bugs before production
- ✅ Test real browser behavior across Chrome/Firefox/Safari
- ✅ Automated visual regression detection
- ✅ Fast parallel execution
- ✅ Integration with existing test pipeline
- ✅ Screenshot/video evidence of failures
- ✅ Reduced manual testing burden
