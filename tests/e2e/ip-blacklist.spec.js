/**
 * E2E: IP Blacklist (#4464) — unified admin tool (ip_blacklist + mass_ip_blacklister).
 * add/remove/list moved to POST /api/ip_blacklist/*. Admin-only (restricted_superdoc).
 * Uses an RFC-5737 documentation IP and removes it, so it's self-cleaning + repeatable.
 */
const { test, expect } = require('@playwright/test');
const { loginAsRoot } = require('./fixtures/auth');

const TEST_IP = '203.0.113.201';

test.describe('IP Blacklist (#4464)', () => {
  test('admin adds a single IP via the API then removes it', async ({ page }) => {
    await loginAsRoot(page);
    await page.goto('/title/IP+Blacklist');

    await page.getByPlaceholder(/one per line/i).fill(TEST_IP);
    await page.getByPlaceholder(/reason for blocking/i).fill('e2e test block');
    await Promise.all([
      page.waitForResponse((r) => r.url().includes('/api/ip_blacklist/add') && r.request().method() === 'POST'),
      page.getByRole('button', { name: /please blacklist/i }).click(),
    ]);
    // the IP now shows in the refreshed table
    const row = page.locator('tr', { hasText: TEST_IP });
    await expect(row).toBeVisible();

    // remove it (self-cleanup)
    await Promise.all([
      page.waitForResponse((r) => r.url().includes('/api/ip_blacklist/remove') && r.request().method() === 'POST'),
      row.getByRole('button', { name: /^Remove$/ }).click(),
    ]);
    await expect(page.locator('tr', { hasText: TEST_IP })).toHaveCount(0);
  });
});
