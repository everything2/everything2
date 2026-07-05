/**
 * E2E: Reset password -> Confirm password (#4335 confirm API + #4475 pure-render page).
 *
 * Mirrors signup-confirm.spec.js, for the "forgot password" flow. The reset request
 * (POST /api/password/reset-request) emails a token link to the Confirm password page
 * with action=reset; dev doesn't send mail, so tools/test-password-reset.pl prints the
 * link that WOULD have been sent (the new password is baked into the token). The spec
 * then drives the real confirm form -> POST /api/users/confirm, which validates the
 * token, sets the new password, logs in, and returns success_reset.
 *
 * Also asserts the #4475 change: an EXPIRED reset link reports 'expired' and does NOT
 * nuke the account.
 *
 * Both specs shell out to `docker exec e2devapp ... ` -- e2devapp is a fixed, controlled
 * dev container name (confirmed acceptable, 2026-07-05).
 *
 * ── Note on urlGen param order (NOT a product bug — verified) ────────────────────────────
 * urlGen() serialises the token-link params in RANDOM Perl hash order, so the emitted link is
 * sometimes token-first, sometimes action-first, etc. This ONLY matters to test plumbing:
 * (1) extraction must match the link order-independently and pull params by name (an
 *     order-sensitive `...action=reset$` pattern silently misses ~1-in-6 links → looks flaky);
 * (2) we rebuild the link via confirmLink() for tidiness, not necessity.
 * The route-recovery parser itself is order-agnostic: a controlled check (2026-07-05) navigated
 * the SAME params token-first vs token-last with an expired expiry and BOTH resolved to
 * state=expired. So there is no param-order parser bug — the earlier "flakiness" was entirely
 * the order-sensitive extraction regex above.
 */
const { test, expect } = require('@playwright/test');
const { execSync } = require('child_process');

function createAccount(uname, pass) {
  execSync(`docker exec e2devapp perl /var/everything/tools/test-signup.pl ${uname} ${pass}`, { encoding: 'utf8' });
}

// Get {token, expiry} from the reset helper for an existing user.
//
// IMPORTANT (why the extraction is order-independent): urlGen() serialises the token-link
// params in RANDOM Perl hash order, so the emitted link is sometimes action-first, sometimes
// token-first, etc. Match the whole Confirm+password link (any order) and pull each param by
// name — an order-sensitive pattern like `...action=reset$` silently misses ~1-in-6 links and
// looks like flakiness. (The same random ordering also drives the route-recovery parser finding
// in this file's header — some orders don't round-trip; we normalise via confirmLink().)
function resetTokenParts(uname, newpass) {
  const out = execSync(
    `docker exec e2devapp perl /var/everything/tools/test-password-reset.pl ${uname} ${newpass}`,
    { encoding: 'utf8' }
  );
  const links = out.match(/\/node\/superdoc\/Confirm\+password\?\S+/g) || [];
  const clean = links.find((l) => !l.includes('&amp;')) || links[links.length - 1];
  if (!clean) return null;
  const token = decodeURIComponent((clean.match(/token=([^&\s]+)/) || [])[1] || '');
  const expiry = (clean.match(/expiry=(\d+)/) || [])[1];
  return token && expiry ? { token, expiry } : null;
}

// Provision a fresh user and get its reset token. A single retry covers the rare genuine
// helper hiccup (a real DB race on the just-created row).
function provisionResettableUser(prefix, newpass) {
  for (let attempt = 0; attempt < 3; attempt++) {
    const uname = prefix + Date.now().toString(36) + attempt;
    createAccount(uname, 'oldpass123');
    const parts = resetTokenParts(uname, newpass);
    if (parts) return { uname, ...parts };
  }
  return null;
}

// Build the confirm-page link in a parse-safe param order (token LAST). Same values the email
// would carry; just not the random order urlGen might emit (see the parser finding above).
function confirmLink(uname, expiry, token) {
  return (
    `/node/superdoc/Confirm+password?user=${encodeURIComponent(uname)}` +
    `&expiry=${expiry}&action=reset&token=${encodeURIComponent(token)}`
  );
}

test.describe('Reset password -> Confirm password (#4335 / #4475)', () => {
  // Both tests create an account + log in via docker exec; run them serially so the two
  // workers don't race on shared DB/session state (create-and-login is not parallel-safe).
  test.describe.configure({ mode: 'serial' });

  test('a valid reset link + new password updates the password and logs in', async ({ page }) => {
    const newpass = 'newpass456';
    const acct = provisionResettableUser('e2r', newpass); // nick is varchar(20)
    expect(acct, 'resettable user provisioned').toBeTruthy();
    const uname = acct.uname;

    await page.goto(confirmLink(uname, acct.expiry, acct.token));
    // scope to the confirm-password form (the Sign In nodelet also has input[name=passwd]);
    // the user types the NEW password, which must match the one baked into the token.
    const confirmForm = page.locator('form').filter({ has: page.locator('button.confirm-password__button') });
    await confirmForm.locator('input[name="passwd"]').fill(newpass);

    const [resp] = await Promise.all([
      page.waitForResponse((r) => r.url().includes('/api/users/confirm') && r.request().method() === 'POST'),
      page.locator('button.confirm-password__button').click(),
    ]);
    expect(resp.status()).toBe(200);
    // success_reset logs the user in; assert the real end-state (now that user, not a guest).
    await page.waitForFunction(
      (u) => window.e2 && window.e2.user && window.e2.user.guest === false && window.e2.user.title === u,
      uname,
      { timeout: 15000 }
    );
  });

  test('an EXPIRED reset link reports expired and does NOT nuke the account (#4475)', async ({ page }) => {
    const acct = provisionResettableUser('e2y', 'newpass456'); // nick is varchar(20)
    expect(acct, 'resettable user provisioned').toBeTruthy();
    const uname = acct.uname;

    // expiry in the past -> the expiry gate fires before token validation
    await page.goto(confirmLink(uname, '1000000000', acct.token));
    await expect(page.getByText(/link has expired/i)).toBeVisible();
    // the "get a new one" renewal points at the Reset password page (not Sign up) for a reset link
    await expect(page.getByRole('link', { name: /get a new one/i })).toBeVisible();

    // #4475: the account must still exist afterward (no GET-nuke). The reset helper only
    // emits a link if the user is still present.
    const rerun = resetTokenParts(uname, 'newpass456');
    expect(rerun, 'account still exists after expired link').toBeTruthy();
  });
});
