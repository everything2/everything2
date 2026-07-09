/**
 * E2E: return-based page path (#4483, api-driven Step 1a/1b).
 *
 * The page render path now RETURNS an Everything::Response (stashed on the request via
 * Router::output / the mod_perlInit short-circuits) that app.psgi finalizes directly, instead of
 * printing header+body into the STDOUT capture. These assertions lock the HTTP-level behaviors that
 * conversion must preserve — a regression (reverting to print, or breaking the stash/finalize edge)
 * shows up here as a wrong status/header/redirect.
 *
 * HTTP-level (Playwright request context); no browser/auth needed.
 */
const { test, expect } = require('@playwright/test');
const { execSync } = require('child_process');

function firstE2nodeId() {
  const out = execSync(
    `docker exec e2devdb mysql -u root -pblah everything -N -e ` +
      `"SELECT node_id FROM node WHERE type_nodetype=(SELECT node_id FROM node WHERE title='e2node' AND type_nodetype=1) ORDER BY node_id LIMIT 1;"`,
    { encoding: 'utf8' }
  );
  return out.trim().split(/\s+/)[0];
}

test.describe('Return-based page path (#4483)', () => {
  test('a normal page renders 200 text/html (1b: Router::output -> stashed Response)', async ({ request }) => {
    const res = await request.get('/title/Writeups+by+Type');
    expect(res.status()).toBe(200);
    expect(res.headers()['content-type']).toMatch(/text\/html/);
    expect((await res.body()).length).toBeGreaterThan(1000); // real body, not empty/header-only
  });

  test('HEAD fast-path returns the right status + X-E2-Head-Optimized (1a, no full render)', async ({ request }) => {
    const wid = firstE2nodeId();
    const ok = await request.head(`/node/${wid}`);
    expect(ok.status()).toBe(200);
    expect(ok.headers()['x-e2-head-optimized']).toBe('1');

    // not-found HEAD -> 404 (return-based header-only Response)
    const nf = await request.head('/node/999999999');
    expect(nf.status()).toBe(404);
  });

  test('the lastnode_id 303 redirect is return-based (1a: gotoNode -> stashed redirect Response)', async ({ request }) => {
    const wid = firstE2nodeId();
    const res = await request.get(`/node/${wid}?lastnode_id=999`, { maxRedirects: 0 });
    expect(res.status()).toBe(303);
    const loc = res.headers()['location'];
    expect(loc).toBeTruthy();
    expect(loc).not.toContain('lastnode_id'); // canonical URL, param stripped
    expect(res.headers()['cache-control']).toContain('no-store');
  });
});
