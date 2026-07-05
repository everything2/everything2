/**
 * E2E: Entity deep-link → content parity (routing epoch, Gap D).
 *
 * Behavior-TRUE-NOW guard for the React-router flip. These admin/dev tools select a target
 * entity from a query param today (?username=, ?id=) and the server renders that entity's
 * data. The router flip must keep the same deep-link → same-entity contract. Two tools:
 *   - show user vars  (?username=<user>)  — admin sees the named user's vars, else self
 *   - Reputation Graph (?id=<writeup>)    — valid writeup id renders; bad id -> error
 *
 * Uses the fixed dev container (e2devdb) to resolve a real writeup id at run time, so the
 * spec survives a reseed (node ids shift, the query does not).
 */
const { test, expect } = require('@playwright/test');
const { execSync } = require('child_process');
const { loginAsRoot } = require('./fixtures/auth');

function aWriteupId() {
  const out = execSync(
    `docker exec e2devdb mysql -u root -pblah everything -N -e "SELECT node_id FROM node WHERE type_nodetype=117 ORDER BY node_id LIMIT 1;"`,
    { encoding: 'utf8' }
  );
  return out.trim().split(/\s+/)[0];
}

test.describe('show user vars — entity deep-link parity (Gap D)', () => {
  test('no username targets the admin themselves; ?username= selects that user', async ({ page }) => {
    await loginAsRoot(page);

    // The controller resolves ?username= into inspect_user; the admin view prefills the
    // username field with the selected user's title (and the vars table below shows their
    // vars). That prefill IS the URL-param -> selected-entity contract the router must keep.
    await page.goto('/title/show+user+vars');
    await expect(page.locator('input[name="username"]')).toHaveValue('root');

    await page.goto('/title/show+user+vars?username=normaluser1');
    await expect(page.locator('input[name="username"]')).toHaveValue('normaluser1');
  });
});

test.describe('Reputation Graph — entity deep-link parity (Gap D)', () => {
  test('a valid writeup id renders the graph; a bogus id degrades to the error state', async ({ page }) => {
    await loginAsRoot(page);
    const wid = aWriteupId();
    expect(wid).toMatch(/^\d+$/);

    // valid: the writeup context renders (admin can view any writeup), not the error blurb
    await page.goto(`/title/Reputation+Graph?id=${wid}`);
    await expect(page.getByText(/Not a valid node/i)).toHaveCount(0);
    // the writeup links back to itself by node_id — proof the id resolved to the entity
    await expect(page.locator(`a[href="/?node_id=${wid}"]`).first()).toBeVisible();

    // bogus id: the id->entity lookup fails and the page shows the terminal error
    await page.goto('/title/Reputation+Graph?id=999999999');
    await expect(page.getByText(/Not a valid node/i)).toBeVisible();
  });
});
