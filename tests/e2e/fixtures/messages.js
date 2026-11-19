/**
 * Private messages in e2e specs, at desktop and phone sizes.
 *
 *   desktop: compose from the Messages nodelet's Compose button; messages show in the
 *            Messages nodelet (#messages), or in the Chatterbox's mini messages when that
 *            nodelet isn't in the sidebar.
 *   mobile:  the bottom nav's Inbox opens a drawer that lists messages and has Compose.
 *
 * The compose box is the shared MessageModal on both.
 */
const { expect } = require('@playwright/test')
const demo = require('./demo')

const NODELETS = { messages: 2044453, chatterbox: 170070 }

/** The user's sidebar nodelet ids (an array), for restoring after a spec changes them. */
async function getNodelets(page) {
  const current = await (await page.request.get('/api/nodelets')).json()
  return (current.nodelets || []).map((n) => Number(n.node_id))
}
async function setNodelets(page, ids) {
  const resp = await page.request.post('/api/nodelets', { data: { nodelet_ids: ids } })
  expect((await resp.json()).success).toBeTruthy()
}

/**
 * Open the compose box. from: 'nodelet' (desktop: Messages nodelet; phone: Inbox drawer) or
 * 'chatterlight' (the Messages box in the Chatterlight page header, on either device).
 */
async function openCompose(actor, { from = 'nodelet' } = {}) {
  const { page } = actor
  if (from === 'chatterlight') {
    await demo.click(page.locator('.chatterlight__header-nodelet button', { hasText: 'Compose' }))
  } else if (actor.device === 'mobile') {
    await demo.click(page.locator('.mobile-bottom-nav button', { hasText: 'Inbox' }))
    await demo.click(page.locator('button[aria-label="Compose new message"]'))
  } else {
    await demo.click(page.locator('#messages button', { hasText: 'Compose' }))
  }
  await page.locator('#message-modal-compose-textarea').waitFor({ state: 'visible', timeout: 10000 })
}

/** Compose and send a message of several lines (Enter between them) through the real compose box. */
async function sendMessage(actor, to, lines, { from = 'nodelet' } = {}) {
  const { page } = actor
  await openCompose(actor, { from })
  const recipient = page.locator('.message-modal-input').first()
  await recipient.fill(to)
  // Pick the suggestion whose title is exactly the recipient (others may only contain it).
  const exact = new RegExp(`^\\s*${to.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\s*$`)
  const suggestion = page.locator('.message-modal-suggestion')
    .filter({ has: page.locator('.message-modal-suggestion-title', { hasText: exact }) }).first()
  if (await suggestion.isVisible({ timeout: 3000 }).catch(() => false)) await suggestion.click()
  // Make sure the suggestion list is closed and stays closed. Left open, it covers the top of
  // the message box, and a late search response can reopen it after a selection; then a click
  // meant for the box lands in the list or the To field instead.
  const list = page.locator('.message-modal-autocomplete')
  for (let tries = 0; tries < 4; tries++) {
    await page.waitForTimeout(600)    // let any pending recipient search finish
    if (!(await list.isVisible().catch(() => false))) break
    await recipient.press('Escape')
  }
  await expect(list).toBeHidden({ timeout: 5000 })
  await expect(recipient).toHaveValue(to)

  // Before sending: the typed lines are all in the message box, and the To field still holds
  // only the recipient. A misdirected keystroke fails there, not later at the display checks.
  await typeAndSend(page, lines, {
    recipientCheck: async () => { await expect(recipient).toHaveValue(to); await expect(list).toBeHidden() },
  })
}

/** Type lines into the open compose box (Enter between them), check where they went, and send. */
async function typeAndSend(page, lines, { recipientCheck } = {}) {
  const box = page.locator('#message-modal-compose-textarea')
  await box.click()
  await expect(box).toBeFocused()
  for (let i = 0; i < lines.length; i++) {
    if (i > 0) await page.keyboard.press('Enter')
    if (lines[i]) await page.keyboard.type(lines[i], { delay: demo.DEMO ? 25 : 0 })
  }
  await expect(box).toHaveValue(lines.join('\n'))
  if (recipientCheck) await recipientCheck()
  await demo.show(box)
  const sent = page.waitForResponse((r) => r.url().includes('/api/messages/create') && r.request().method() === 'POST')
  await demo.click(page.locator('.message-modal-btn--send'))
  expect((await sent).status()).toBe(200)
  await box.waitFor({ state: 'hidden', timeout: 10000 })
}

/**
 * Reply to a listed message through its reply button (all: reply to the whole group). The
 * reply dialog shows the recipient instead of a To field; checks it names `expectTo`.
 */
async function replyTo(page, messageText, lines, { all = false, expectTo } = {}) {
  const item = messageText.locator('xpath=ancestor::*[.//button[contains(@class,"message-list-action-btn--reply")]][1]')
  const button = item.locator(`button[title="${all ? 'Reply to all group members' : 'Reply to sender'}"]`).first()
  await demo.click(button)
  await page.locator('#message-modal-compose-textarea').waitFor({ state: 'visible', timeout: 10000 })
  const to = page.locator('.message-modal-recipient-display')
  if (expectTo) await expect(to).toContainText(expectTo)
  await typeAndSend(page, lines, { recipientCheck: expectTo ? () => expect(to).toContainText(expectTo) : undefined })
}

/** Send a private message from the Chatterbox input with /msg (one line, as the input allows). */
async function msgFromChatterbox(page, to, text) {
  const input = page.locator('#chatterbox input.chatter-input')
  await input.click()
  await input.fill(`/msg ${to} ${text}`)
  const posted = page.waitForResponse((r) => r.request().method() === 'POST' && /\/api\/(chatter|messages)/.test(r.url()))
  await demo.click(page.locator('#chatterbox button[type="submit"]', { hasText: 'talk' }))
  expect((await posted).status()).toBe(200)
}

/**
 * Where the user's messages are listed: returns the message-text elements. Desktop reads the
 * Messages nodelet (or the Chatterbox mini messages); phone opens the Inbox drawer.
 */
async function messageTexts(actor, { where = 'nodelet' } = {}) {
  const { page } = actor
  if (actor.device === 'mobile') {
    await demo.click(page.locator('.mobile-bottom-nav button', { hasText: 'Inbox' }))
    return page.locator('.mobile-message-body')
  }
  const scope = where === 'chatterbox' ? '#chatterbox' : '#messages'
  return page.locator(`${scope} .message-list-content`)
}

/**
 * The text as the browser lays it out. innerText (unlike textContent) follows rendering, so
 * it contains line breaks only where they actually show on screen.
 */
async function renderedText(locator) {
  return locator.evaluate((el) => el.innerText)
}

module.exports = { NODELETS, getNodelets, setNodelets, openCompose, sendMessage, typeAndSend, replyTo, msgFromChatterbox, messageTexts, renderedText }
