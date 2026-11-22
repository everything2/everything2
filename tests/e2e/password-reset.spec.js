/**
 * E2E: Reset password -> Confirm password (#4335 confirm API + #4475 pure-render page).
 *
 * The whole "forgot password" path, as an active member goes through it:
 *   1. the Reset password form (POST /api/password/reset-request) -> the reset email;
 *   2. the link in that email -> the Confirm password form -> POST /api/users/confirm,
 *      which sets the new password and signs them in;
 *   3. a fresh session signs in with the new password, and the old one no longer works.
 *
 * Dev sends no mail. node2mail keeps each message in the dev mail spool instead, and
 * `tools/test-password-reset.pl --sent <user>` prints the newest one and the link in it,
 * so the spec follows the link from the very email the form produced.
 *
 * The account is activated and used first (setup, not recorded): the reset request sends
 * an activation link instead to an account that has never been used.
 *
 * Watch it: `./tools/e2e-demo.sh password-reset` (E2E_DEMO_DEVICE=mobile for phones).
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
const { loginAs } = require('./fixtures/auth');
const demo = require('./fixtures/demo');
const { activeAccount } = require('./fixtures/signup');

function createAccount(uname, pass) {
  return execSync(`docker exec e2devapp perl /var/everything/tools/test-signup.pl ${uname} ${pass}`, { encoding: 'utf8' });
}

// The newest email sent to a user, read with tools/test-password-reset.pl --sent (shown on the
// recording as a harness card): { to, subject, link }, link pointed at the local dev server.
const { sentEmail } = require('./fixtures/email');

// The confirm form on the Confirm password page (the Sign In nodelet also has input[name=passwd]).
const confirmFormOf = (page) =>
  page.locator('form').filter({ has: page.locator('button.confirm-password__button') });

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

  test('a member resets a forgotten password with the emailed link', async ({ browser }) => {
    test.setTimeout(demo.DEMO ? 180000 : 90000);
    const uname = 'e2r' + Date.now().toString(36); // nick is varchar(20)
    const oldpass = 'oldpass123';
    const newpass = 'newpass456';
    const user = await demo.actor(browser, `${uname} (forgot password)`, '#38495e');
    const { page } = user;
    const loggedInAs = (u) => page.waitForFunction(
      (name) => window.e2 && window.e2.user && window.e2.user.guest === false && window.e2.user.title === name,
      u,
      { timeout: 15000 }
    );

    // Where the signed-in user shows: the Epicenter nodelet on desktop, the profile menu on phones.
    const showSignedIn = async (caption) => {
      const who = user.device === 'mobile' ? page.locator('.e2-header-mobile-auth') : page.locator('#epicenter');
      if (user.device !== 'mobile') await expect(who).toContainText(uname, { timeout: 10000 });
      await demo.step(page, caption);
      await demo.show(who, 2500);
    };

    await demo.scenario('password-reset', [user], async () => {
      // Setup (harness): an active account with a known old password.
      await page.goto('/');
      await activeAccount(browser, user, uname, oldpass);

      // 1. The Reset password form.
      await page.goto('/node/superdoc/Reset+password');
      await demo.step(page, 'forgot their password: opens Reset password');
      const form = page.locator('.reset-password form');
      await demo.show(form);
      await demo.step(page, 'enters their username and a new password');
      await form.locator('#who').fill(uname);
      await form.locator('#password').fill(newpass);
      await form.locator('#passwordConfirm').fill(newpass);
      const [requested] = await Promise.all([
        page.waitForResponse((r) => r.url().includes('/api/password/reset-request') && r.request().method() === 'POST'),
        demo.click(form.locator('button[type="submit"]')),
      ]);
      expect((await requested.json()).success).toBeTruthy();
      const sentNote = page.locator('.reset-password__success');
      await expect(sentNote).toContainText('Your password reset link is on its way');
      await demo.step(page, 'told the reset link is on its way');
      await demo.show(sentNote);

      // 2. The email that request sent, and the link in it.
      const mail = await sentEmail(user, uname);
      expect(mail.to).toContain(`${uname}@test.example.com`);
      expect(mail.subject).toBe('Everything2 password reset');
      expect(mail.link, 'Confirm password link in the email').toBeTruthy();
      expect(mail.link).toContain('action=reset');

      await page.goto(mail.link);
      await demo.step(page, 'opened the link from the reset email');
      const confirmForm = confirmFormOf(page);
      await demo.show(confirmForm);
      await demo.step(page, 'enters the new password');
      await confirmForm.locator('input[name="passwd"]').fill(newpass);
      const [confirmed] = await Promise.all([
        page.waitForResponse((r) => r.url().includes('/api/users/confirm') && r.request().method() === 'POST'),
        demo.click(page.locator('button.confirm-password__button')),
      ]);
      expect(confirmed.status()).toBe(200);
      // success_reset signs them in and sends them to the front page.
      await loggedInAs(uname);
      await showSignedIn('password reset: signed in');

      // 3. A fresh session: the new password works through the normal sign-in form...
      await demo.step(page, 'starts a fresh session');
      await page.context().clearCookies();
      await demo.step(page, 'signs in with the new password');
      await loginAs(page, uname, newpass);
      await loggedInAs(uname);
      await showSignedIn('signed in with the new password');

      // ...and the old password no longer does.
      const probe = await browser.newContext();
      const old = await probe.request.post('/api/sessions/create', { data: { username: uname, passwd: oldpass } });
      const oldWorks = old.status() === 200 && (await old.text()).includes(`"${uname}"`);
      await probe.close();
      expect(oldWorks, 'old password rejected').toBe(false);
      await demo.note(user, 'tries the old password: rejected',
        `POST /api/sessions/create as ${uname} with the old password, from a separate session -> HTTP ${old.status()}, not signed in`);
    });
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
