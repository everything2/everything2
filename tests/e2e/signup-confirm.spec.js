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
 *
 * The "through the Sign Up form" tests drive the real form (POST /api/signup) and follow the
 * activation link from the email that request sent: dev keeps outgoing mail in a spool, read
 * with `tools/test-password-reset.pl --sent` (fixtures/email.js), shown on recordings as a
 * TEST HARNESS card. Watch: `./tools/e2e-demo.sh signup-confirm` (E2E_DEMO_DEVICE=mobile too).
 */
const { test, expect } = require('@playwright/test');
const { execSync } = require('child_process');
const demo = require('./fixtures/demo');
const { sentEmail } = require('./fixtures/email');
const { signUpThroughForm, activateWith } = require('./fixtures/signup');

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

  test('two people sign up through the form; each activates with their own emailed link', async ({ browser }) => {
    test.setTimeout(demo.DEMO ? 240000 : 90000);
    const stamp = Date.now().toString(36);
    const people = [
      { uname: `e2a${stamp}`, pass: 'firstpass123', color: '#38495e' },
      { uname: `e2b${stamp}`, pass: 'secondpass123', color: '#2f6f8f' },
    ];
    for (const p of people) {
      p.email = `${p.uname}@test.example.com`;
      p.actor = await demo.actor(browser, `${p.uname} (new member)`, p.color);
    }
    const actors = people.map((p) => p.actor);

    await demo.scenario('signup-two-people', actors, async () => {
      // One after the other, the way two signups land on the site.
      for (const p of people) await signUpThroughForm(p.actor, p.uname, p.pass, p.email);

      for (const p of people) {
        const mail = await sentEmail(p.actor, p.uname);
        expect(mail.subject).toBe('Welcome to Everything2');
        expect(mail.to).toContain(p.email);
        expect(mail.link).toContain('action=activate');
        expect(mail.link).toContain(`user=${p.uname}`); // their own link, not the other person's
        await activateWith(p.actor, mail.link, p.pass, p.uname);
      }
    });
  });

  test('a lost activation email: Reset password sends a new activation link that works', async ({ browser }) => {
    test.setTimeout(demo.DEMO ? 180000 : 90000);
    const uname = `e2l${Date.now().toString(36)}`;
    const email = `${uname}@test.example.com`;
    const member = await demo.actor(browser, `${uname} (lost the email)`, '#38495e');
    const { page } = member;

    await demo.scenario('signup-lost-activation', [member], async () => {
      await signUpThroughForm(member, uname, 'firstpass123', email);
      await demo.note(member, 'the activation email is "lost"', 'The test never opens it: the member asks for a new link instead.');

      await page.goto('/node/superdoc/Reset+password');
      await demo.step(page, 'asks for a new link on Reset password');
      const form = page.locator('.reset-password form');
      await form.locator('#who').fill(uname);
      await form.locator('#password').fill('chosenpass123');
      await form.locator('#passwordConfirm').fill('chosenpass123');
      await demo.click(form.locator('button[type="submit"]'));
      const sent = page.locator('.reset-password__success');
      await expect(sent).toContainText('new account activation link');
      await demo.step(page, 'told a new activation link is on its way');
      await demo.show(sent);

      const mail = await sentEmail(member, uname);
      expect(mail.subject).toBe('Welcome to Everything2');
      expect(mail.raw).not.toMatch(/<(servername|link|name)>/); // every placeholder filled
      expect(mail.link).toContain('action=activate');
      expect(mail.link).toContain(`user=${uname}`);
      await activateWith(member, mail.link, 'chosenpass123', uname);
    });
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
