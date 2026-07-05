/**
 * E2E: Websterbless (#4451). Editor/admin blesses Webster-correction users via
 * POST /api/websterbless/bless. Bogus username -> per-user error, no mutation. Happy path: t/184.
 */
const { test, expect } = require('@playwright/test');
const { loginAsRoot } = require('./fixtures/auth');

test.describe('Websterbless (#4451)', () => {
  test('editor/admin submits; a bogus user yields a per-user error', async ({ page }) => {
    await loginAsRoot(page);
    await page.goto('/title/Websterbless');
    await page.locator('input[name="webbyblessUser0"]').fill('no_such_user_e2e_xyz');
    await Promise.all([
      page.waitForResponse((r) => r.url().includes('/api/websterbless/bless') && r.request().method() === 'POST'),
      page.getByRole('button', { name: 'Websterbless' }).click(),
    ]);
    await expect(page.getByText(/couldn't find user/i)).toBeVisible();
  });
});
