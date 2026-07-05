/**
 * E2E: Usergroup Message Archive (#4472). Member opens a group and sees the fetch-driven copy form
 * (copy-to-self moved to POST /api/usergroup_message_archive/copy). Load + group-nav + role-gating;
 * the copy mutation is covered by t/193 (avoids inbox residue here).
 */
const { test, expect } = require('@playwright/test');
const { loginAsRoot, visitAsGuest } = require('./fixtures/auth');

test.describe('Usergroup Message Archive (#4472)', () => {
  test('a member opens a group and sees the copy form', async ({ page }) => {
    await loginAsRoot(page); // root is a member of edev (archive-enabled)
    await page.goto('/title/usergroup+message+archive');
    await expect(page.getByText(/Choose from/)).toBeVisible();
    await page.getByRole('link', { name: 'edev' }).first().click();
    await expect(page.getByRole('button', { name: /Copy selected messages/i })).toBeVisible();
  });
  test('a guest is told to log in', async ({ page }) => {
    await visitAsGuest(page);
    await page.goto('/title/usergroup+message+archive');
    await expect(page.getByText(/must login to use this feature/i)).toBeVisible();
  });
});
