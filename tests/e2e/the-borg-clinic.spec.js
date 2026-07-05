/**
 * E2E: The Borg Clinic (#4449). Admin sets a user's numborged via POST /api/borgclinic/setborg.
 * Load + admin-gating + the always-visible lookup form. The set mutation is covered by t/183.
 */
const { test, expect } = require('@playwright/test');
const { loginAsRoot } = require('./fixtures/auth');

test.describe('The Borg Clinic (#4449)', () => {
  test('admin sees the borg-clinic lookup form', async ({ page }) => {
    await loginAsRoot(page);
    await page.goto('/title/The+Borg+Clinic');
    await expect(page.getByText(/Who needs to be looked at/i)).toBeVisible();
    await expect(page.getByRole('button', { name: /Do it!/ }).first()).toBeVisible();
  });
});
