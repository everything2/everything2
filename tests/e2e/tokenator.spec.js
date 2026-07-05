/**
 * E2E: The Tokenator (#4455). Admin gives users a "token" via POST /api/the_tokenator/tokenate.
 * A bogus username exercises the full browser round-trip (form -> API -> per-user result) with
 * zero mutation. Happy-path token grant is covered by t/186.
 */
const { test, expect } = require('@playwright/test');
const { loginAsRoot } = require('./fixtures/auth');

test.describe('The Tokenator (#4455)', () => {
  test('admin submits usernames; a bogus user yields a per-user not-found result', async ({ page }) => {
    await loginAsRoot(page);
    await page.goto('/title/The+Tokenator');
    await page.getByPlaceholder('Username').first().fill('no_such_user_e2e_xyz');
    await Promise.all([
      page.waitForResponse((r) => r.url().includes('/api/the_tokenator/tokenate') && r.request().method() === 'POST'),
      page.getByRole('button', { name: /give tokens/i }).click(),
    ]);
    await expect(page.getByText(/couldn't find user/i)).toBeVisible();
  });
});
