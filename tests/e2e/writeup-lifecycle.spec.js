const { test, expect } = require('@playwright/test')
const { loginAsE2EUser } = require('./fixtures/auth')
const { createWriteup } = require('./fixtures/content')

/**
 * Writeup lifecycle (object model).
 *
 * Exercises the core node lifecycle that everything else is built on: a draft is
 * created, attached to an e2node, then published -- which converts the draft node
 * IN PLACE to a writeup (a type sqlUpdate, not a new node) and joins it to the
 * e2node's nodegroup. This is the edge case the publish path has to get right
 * (type conversion + cache invalidation + nodegroup membership).
 */
test.describe('Writeup lifecycle (object model)', () => {
  test('publishing a draft converts it in place to a writeup on its e2node', async ({ page }) => {
    await loginAsE2EUser(page)

    const title = `E2E lifecycle ${Date.now()}`
    const { draftId, e2nodeId, writeupId } = await createWriteup(page, { title })

    expect(e2nodeId).toBeTruthy()
    expect(writeupId).toBe(draftId) // converted in place: same node, new type

    // The writeup node itself renders (it exists as a real node).
    const wuResp = await page.request.get(`/node/${writeupId}`)
    expect(wuResp.ok()).toBe(true)

    // And it renders under its e2node (it joined the e2node's nodegroup), which is
    // the object-model outcome we care about: a published writeup is reachable
    // through its parent e2node.
    const e2nodeResp = await page.request.get(`/node/${e2nodeId}`)
    expect(e2nodeResp.ok()).toBe(true)
    expect(await e2nodeResp.text()).toContain(title)
  })
})
