/**
 * E2E: Nate's Secret Unborg Doc (#4468)
 * Admin-only. GET-mutation removed; "Unborg me" now POSTs /api/nate_s_secret_unborg_doc/unborg
 * and reloads on success so the chrome (chat) re-enables. Self-targeting (unborgs the caller);
 * root isn't borged so it's a safe no-op that still exercises the POST + reload.
 */
const { test, expect } = require('@playwright/test');
const { loginAsRoot } = require('./fixtures/auth');

test.describe("Nate's Secret Unborg Doc (#4468)", () => {
  test('admin unborg button POSTs the API and reloads', async ({ page }) => {
    await loginAsRoot(page);
    await page.goto("/title/nate%27s+secret+unborg+doc");
    const btn = page.getByRole('button', { name: /unborg me/i });
    await expect(btn).toBeVisible();
    const [resp] = await Promise.all([
      page.waitForResponse((r) => r.url().includes('/api/nate_s_secret_unborg_doc/unborg') && r.request().method() === 'POST'),
      btn.click(),
    ]);
    expect(resp.status()).toBe(200);
    // reload-on-success re-renders the tool for the admin
    await expect(page.getByRole('button', { name: /unborg me/i })).toBeVisible();
  });
});
