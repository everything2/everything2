/**
 * E2E: Sign Up -> Confirm Password activation (#4335 confirm API + #4475 pure-render page).
 *
 * Uses the tools/test-signup.pl helper to simulate the activation email: it creates the
 * unactivated account and prints the activation link (dev doesn't send mail). The spec then
 * drives the real confirm_password login form -> POST /api/users/confirm, which validates the
 * token, sets the password, logs in, and returns success_activate.
 *
 * Also asserts the #4475 change: an EXPIRED activation link now reports 'expired' and does
 * NOT nuke the account (the account still exists afterward).
 */
const { test, expect } = require('@playwright/test');
const { execSync } = require('child_process');

function makeSignup(uname, pass) {
  const out = execSync(
    `docker exec e2devapp perl /var/everything/tools/test-signup.pl ${uname} ${pass}`,
    { encoding: 'utf8' }
  );
  const links = out.match(/\/node\/superdoc\/Confirm\+password\?[^\s"<]+/g) || [];
  // the clean (non-HTML-entity) link is the standalone one
  return links.find((l) => !l.includes('&amp;')) || links[links.length - 1];
}

test.describe('Sign Up -> Confirm Password (#4335 / #4475)', () => {
  test('a valid activation link + password activates the account and logs in', async ({ page }) => {
    const uname = 'e2e_' + Date.now().toString(36); // nick is varchar(20)
    const pass = 'e2epass123';
    const link = makeSignup(uname, pass);
    expect(link, 'activation link from helper').toBeTruthy();

    await page.goto(link);
    // scope to the confirm-password form (the Sign In nodelet also has input[name=passwd])
    const confirmForm = page.locator('form').filter({ has: page.locator('button.confirm-password__button') });
    await confirmForm.locator('input[name="passwd"]').fill(pass);

    const [resp] = await Promise.all([
      page.waitForResponse((r) => r.url().includes('/api/users/confirm') && r.request().method() === 'POST'),
      page.locator('button.confirm-password__button').click(),
    ]);
    expect(resp.status()).toBe(200);
    // success_activate logs the user in and the component redirects to their profile;
    // assert the real end-state: we're now that user (not a guest).
    await page.waitForFunction(
      (u) => window.e2 && window.e2.user && window.e2.user.guest === false && window.e2.user.title === u,
      uname,
      { timeout: 15000 }
    );
  });

  test('an EXPIRED activation link reports expired and does NOT nuke the account (#4475)', async ({ page }) => {
    const uname = 'e2x_' + Date.now().toString(36); // nick is varchar(20)
    const pass = 'e2epass123';
    const link = makeSignup(uname, pass);
    // rewrite the expiry param to the past -> the expiry gate fires before token validation
    const expiredLink = link.replace(/expiry=\d+/, 'expiry=1000000000');

    await page.goto(expiredLink);
    await expect(page.getByText(/link has expired/i)).toBeVisible();

    // #4475: the account must still exist (no GET-nuke). The helper re-run finds the existing user.
    const rerun = execSync(
      `docker exec e2devapp perl /var/everything/tools/test-signup.pl ${uname} ${pass}`,
      { encoding: 'utf8' }
    );
    expect(rerun).toMatch(/already exists/i);
  });
});
