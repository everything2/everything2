/**
 * E2E: Writeups by Type — URL-param → content parity (routing epoch, Gap C).
 *
 * Behavior-TRUE-NOW guard for the React-router flip. This page is server-rendered today
 * and reads wutype/count/page from the query string. These assertions pin the current
 * URL→state contract so that when the client router takes over navigation, the same URLs
 * must still (a) reflect the filter selection into the form and (b) round-trip the filter
 * params through pagination links. If the flip breaks either, this spec fails.
 *
 * Public page — no auth needed.
 */
const { test, expect } = require('@playwright/test');

test.describe('Writeups by Type — routing parity (Gap C)', () => {
  test('the wutype + count query params are reflected into the filter selects', async ({ page }) => {
    // 251 = the "idea" writeuptype (stable seed id)
    await page.goto('/title/Writeups+by+Type?wutype=251&count=25');

    await expect(page.locator('select.writeups-by-type__select--type')).toHaveValue('251');
    // the results-per-page select mirrors the count param
    const selects = page.locator('.writeups-by-type select');
    await expect(selects.nth(1)).toHaveValue('25');
  });

  test('pagination links round-trip the page-size + page params (the round-trip the router must preserve)', async ({ page }) => {
    // page 1 with the smallest valid page size (the controller clamps count to >=10) across
    // all writeups (dev has 260+), so page 1 is non-empty, the Prev control renders, and its
    // href must carry the page size forward and decrement the page.
    await page.goto('/title/Writeups+by+Type?count=10&page=1');

    const prev = page.locator('a.writeups-by-type__nav-link', { hasText: /prev/i });
    await expect(prev).toBeVisible();
    const href = await prev.getAttribute('href');
    // going back a page keeps the page size (count=10) and drops to page=0
    expect(href).toContain('count=10');
    expect(href).toContain('page=0');
  });

  // SSR == client-router parity. Since #4524 the page is a pure gate: the controller (and so
  // /api/pagestate, the client router's path) ships only { type }, and React reads the filters
  // off the URL and fetches /api/writeups_by_type. So parity means: the gate carries no
  // param-derived state, and the URL's filters reach the list API, which reports them back as
  // integers (#4152).
  test('routing parity: the page gate ships only its type; the URL filters drive the list API', async ({ page, request }) => {
    const res = await request.get(
      `/api/pagestate/lookup/superdoc/${encodeURIComponent('Writeups by Type')}?wutype=251&count=25&page=1`
    );
    expect(res.ok()).toBe(true);
    const cd = (await res.json()).contentData;
    expect(cd.type).toBe('writeups_by_type');
    expect(Object.keys(cd).filter((k) => k.startsWith('current_'))).toEqual([]);

    const listCall = page.waitForResponse((r) => r.url().includes('/api/writeups_by_type'));
    await page.goto('/title/Writeups+by+Type?wutype=251&count=25&page=1');
    const list = await listCall;
    const asked = new URL(list.url()).searchParams;
    expect([asked.get('wutype'), asked.get('count'), asked.get('page')]).toEqual(['251', '25', '1']);
    const body = await list.json();
    expect(body.current_type).toBe(251);   // integer contract (#4152)
    expect(body.current_count).toBe(25);
    expect(body.current_page).toBe(1);
  });
});
