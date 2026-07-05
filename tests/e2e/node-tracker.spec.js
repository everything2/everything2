/**
 * E2E: Node Tracker (#4458)
 *
 * Logged-in self-service tool. Migrated to POST /api/node_tracker/update (the "Update"
 * snapshot-save) + a pure-render page whose intro is real LinkNode anchors. NoGuest-gated.
 * Self-targeting (saves the caller's own tracker row) so it's safe + repeatable.
 */
const { test, expect } = require('@playwright/test');
const { loginAsE2EUser, visitAsGuest } = require('./fixtures/auth');

test.describe('Node Tracker (#4458)', () => {
  test('a logged-in user sees the stats and can Update the snapshot in place', async ({ page }) => {
    await loginAsE2EUser(page);
    await page.goto('/title/Node+Tracker');

    // The stats block + the modernized intro link (#4458: [cow of doom] -> real anchor).
    await expect(page.locator('pre').first()).toContainText('E2 USER INFO');
    await expect(page.getByRole('link', { name: 'cow of doom' })).toHaveAttribute('href', '/title/cow of doom');

    // Update posts to the API and refreshes in place (no full reload); button re-enables.
    const updateBtn = page.getByRole('button', { name: /^Update$/ });
    await expect(updateBtn).toBeVisible();

    const [resp] = await Promise.all([
      page.waitForResponse((r) => r.url().includes('/api/node_tracker/update') && r.request().method() === 'POST'),
      updateBtn.click(),
    ]);
    expect(resp.status()).toBe(200);
    await expect(updateBtn).toBeEnabled();
    // still rendered (no crash / no error banner), stats block intact
    await expect(page.locator('pre').first()).toContainText('E2 USER INFO');
  });

  test('a guest does not get the tool (NoGuest)', async ({ page }) => {
    await visitAsGuest(page);
    await page.goto('/title/Node+Tracker');
    // NoGuest -> login redirect / no Update control for a guest.
    await expect(page.getByRole('button', { name: /^Update$/ })).toHaveCount(0);
  });
});
