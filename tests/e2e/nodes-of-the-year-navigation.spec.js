/**
 * E2E regression: Nodes of the Year filter-form navigation (#4524).
 *
 * Bug: the "Get Writeups" button did `window.location.href = "?" + params`, which REPLACED the whole
 * query string. When the page was reached via a node_id URL (e.g. /index.pl?node_id=<id>), that
 * dropped node_id and dumped the user on the homepage. Fix: build the target from the current URL so
 * the node identifier (pathname or ?node_id=) is preserved and only the filter params change.
 *
 * Uses the fixed dev container to resolve the node id at run time, so the spec survives a reseed.
 */
const { test, expect } = require('@playwright/test');
const { execSync } = require('child_process');
const { loginAsRoot } = require('./fixtures/auth');

function nodeIdForTitle(title) {
  const out = execSync(
    `docker exec e2devdb mysql -u root -pblah everything -N -e "SELECT node_id FROM node WHERE title='${title}' LIMIT 1;"`,
    { encoding: 'utf8' }
  );
  return out.trim().split(/\s+/)[0];
}

test.describe('Nodes of the Year — "Get Writeups" preserves the node (Gap #4524)', () => {
  test('submitting the filter form keeps you on the page (not the homepage) when reached via a node_id URL', async ({ page }) => {
    await loginAsRoot(page);
    const nid = nodeIdForTitle('Nodes of the Year');
    expect(nid).toMatch(/^\d+$/);

    // Reach the page via the node_id entry shape -- the one that used to break on submit.
    await page.goto(`/index.pl?node_id=${nid}`);
    await expect(page.locator('.nodes-of-year')).toBeVisible();

    // Submit the filter form; it triggers a full-page navigation.
    await Promise.all([
      page.waitForURL(/year=/),
      page.locator('.nodes-of-year__submit-button').click(),
    ]);

    // Still on Nodes of the Year (node preserved), NOT bounced to the homepage.
    await expect(page.locator('.nodes-of-year')).toBeVisible();
    expect(page.url()).toContain(`node_id=${nid}`);
    expect(page.url()).toMatch(/year=/);
  });
});
