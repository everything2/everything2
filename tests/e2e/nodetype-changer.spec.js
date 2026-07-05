/**
 * E2E: Nodetype Changer (#4461). Admin lookup+change via POST /api/nodetype_changer/lookup|change.
 * Exercises the read-only lookup + the permanent-cache WARNING on selecting a cached type -- no
 * change is submitted (zero mutation). The confirm-gated change is covered by t/188.
 */
const { test, expect } = require('@playwright/test');
const { loginAsRoot } = require('./fixtures/auth');

test.describe('Nodetype Changer (#4461)', () => {
  test('admin looks up a node; selecting a permanent-cache type surfaces the warning', async ({ page }) => {
    await loginAsRoot(page);
    await page.goto('/title/Nodetype+Changer');

    await page.getByPlaceholder('Enter node ID').fill('1');
    await Promise.all([
      page.waitForResponse((r) => r.url().includes('/api/nodetype_changer/lookup') && r.request().method() === 'POST'),
      page.getByRole('button', { name: /get data/i }).click(),
    ]);

    const select = page.locator('select.nodetype-changer__select');
    await expect(select).toBeVisible();
    // pick a permanent-cache-flagged option by value; the client-side warning must appear
    const permValue = await select.locator('option', { hasText: 'permanent cache' }).first().getAttribute('value');
    await select.selectOption(permValue);
    await expect(page.getByRole('alert')).toContainText(/permanent/i);
  });
});
