/**
 * E2E: E2 Penny Jar (#4454). Logged-in give/take (GP) via POST /api/e2_penny_jar/give|take.
 * Load + role-gating only (no mutation -- avoids GP/jar state churn); API paths covered by t/185.
 */
const { test, expect } = require('@playwright/test');
const { loginAsE2EUser, visitAsGuest } = require('./fixtures/auth');

test.describe('E2 Penny Jar (#4454)', () => {
  test('a logged-in user sees the jar state', async ({ page }) => {
    await loginAsE2EUser(page);
    await page.goto('/title/E2+Penny+Jar');
    await expect(page.getByText(/You currently have/)).toBeVisible();
  });
  test('a guest is told to log in', async ({ page }) => {
    await visitAsGuest(page);
    await page.goto('/title/E2+Penny+Jar');
    await expect(page.getByText(/logged in to touch the pennies/i)).toBeVisible();
  });
});
