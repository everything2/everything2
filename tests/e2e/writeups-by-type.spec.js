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
});
