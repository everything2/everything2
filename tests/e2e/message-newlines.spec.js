const { test, expect } = require('@playwright/test')
const { loginAs } = require('./fixtures/auth')
const demo = require('./fixtures/demo')
const msg = require('./fixtures/messages')

/**
 * Messages keep their line breaks everywhere they're shown (#4006).
 *
 * Every check reads the element's innerText, which follows what's on screen, so it has real
 * line breaks only where the browser draws them. The compose helpers also check, before
 * sending, that the typed lines are in the message box and the recipient is untouched, so a
 * failure here is about display, never about typing landing in the wrong field.
 *
 * Private (normaluser25 -> normaluser26, used only by this spec):
 *   - recipient: Messages nodelet (phone: Inbox drawer), Message Inbox, Inbox filtered by
 *     sender, Chatterbox mini messages and a multi-line reply typed from them (desktop), a
 *     multi-line reply through the Inbox's reply dialog, the Archived view;
 *   - sender: both replies in their messages, the Chatterlight page (its header Messages box
 *     shows a reply, and a multi-line message composed there arrives intact), the Sent tab
 *     unfiltered and filtered by recipient (#4701), the Message Outbox page, and /msg from the
 *     Chatterbox (one line) arriving intact (desktop).
 *   The Chatterbox and Chatterlight chat input itself is one line (an <input>); multi-line
 *   typing in the chat components happens in their message dialogs, covered here.
 * Usergroup (genericdev -> edev): the sender's own Inbox copy, a multi-line reply-all, Sent
 *   filtered to the group (#4701), and the usergroup message archive.
 *
 * Sidebars are restored and private messages deleted afterwards (the archive is a log).
 * Watch: `./tools/e2e-demo.sh message-newlines` (E2E_DEMO_DEVICE=mobile too).
 */
const SENDER = 'normaluser25'
const RECIPIENT = 'normaluser26'

const lineCheck = async (page, locator, expected, caption, { contains = false } = {}) => {
  await expect(locator).toBeVisible({ timeout: 15000 })
  const text = await msg.renderedText(locator)
  if (contains) expect(text).toContain(expected)
  else expect(text).toBe(expected)
  await demo.step(page, caption)
  await demo.show(locator, 2000)
}

// The filters panel on Message Inbox: filter by one user (Sender on Inbox, Recipient on Sent).
const filterBy = async (page, name) => {
  await demo.click(page.locator('.message-inbox-filters-toggle'))
  const input = page.locator('.message-inbox-filters-panel .user-search__input')
  await input.fill(name)
  await demo.click(page.locator('.user-search__suggestion', { has: page.locator('.user-search__user-name', { hasText: new RegExp(`^${name}$`) }) }).first())
  await expect(page.locator('.message-inbox-filter-chip', { hasText: name })).toBeVisible({ timeout: 10000 })
}

test.describe('Message line breaks', () => {
  test.setTimeout(demo.DEMO ? 420000 : 150000)

  test('private messages keep their line breaks across inbox, replies, sent, archive and chatterbox', async ({ browser }) => {
    const stamp = Date.now().toString(36)
    const lines = [`Hi from the newline check ${stamp}`, 'this is line two', '', 'and line four, after a blank line']
    const reply = [`Inbox reply ${stamp}`, 'got it, on two lines']
    const chatReply = [`Chatterbox reply ${stamp}`, 'typed from the Chatterbox', 'on three lines']
    const fromChatterlight = [`From Chatterlight ${stamp}`, '', 'with a blank line between']
    const shown = lines.join('\n')
    const sender = await demo.actor(browser, `${SENDER} (sends)`, '#38495e')
    const recipient = await demo.actor(browser, `${RECIPIENT} (receives)`, '#2f6f8f')
    const desktop = recipient.device !== 'mobile'
    const before = {}

    const cleanup = async () => {
      for (const [who, outbox] of [[recipient, false], [sender, false], [sender, true]]) {
        const list = await (await who.page.request.get(`/api/messages/?limit=50${outbox ? '&outbox=1' : ''}`)).json().catch(() => [])
        for (const archived of [0, 1]) {
          const rows = archived && !outbox
            ? await (await who.page.request.get('/api/messages/?limit=50&archive=1')).json().catch(() => [])
            : list
          for (const m of [].concat(rows.messages || rows || [])) {
            if (!String(m.msgtext || '').includes(stamp)) continue
            await who.page.request.post(`/api/messages/${m.message_id}/action/${outbox ? 'delete_outbox' : 'delete'}`).catch(() => {})
          }
        }
      }
      for (const a of [sender, recipient]) {
        if (before[a.label]) await msg.setNodelets(a.page, before[a.label]).catch(() => {})
      }
    }

    await demo.scenario('message-newlines', [sender, recipient], async () => {
      await Promise.all([loginAs(sender.page, SENDER, 'blah'), loginAs(recipient.page, RECIPIENT, 'blah')])
      for (const a of [sender, recipient]) {
        before[a.label] = await msg.getNodelets(a.page)
        const want = [msg.NODELETS.messages, msg.NODELETS.chatterbox]
        await msg.setNodelets(a.page, [...want, ...before[a.label].filter((id) => !want.includes(id))])
        await a.page.reload()
      }

      // 1. Compose and send.
      await demo.step(sender.page, `writes ${RECIPIENT} a message over several lines`)
      await msg.sendMessage(sender, RECIPIENT, lines)

      // 2. Recipient: Messages nodelet / Inbox drawer.
      await recipient.page.reload()
      const where = (await msg.messageTexts(recipient)).filter({ hasText: `newline check ${stamp}` }).first()
      await lineCheck(recipient.page, where, shown, desktop ? 'Messages nodelet: line breaks show' : 'Inbox drawer: line breaks show')

      // 3. Recipient: Message Inbox, then filtered by sender.
      await recipient.page.goto('/title/Message+Inbox')
      // The Inbox page's own list (the Messages nodelet in the sidebar shows the same message).
      const inboxItem = () => recipient.page.locator('.message-inbox .message-list-content', { hasText: `newline check ${stamp}` }).first()
      await lineCheck(recipient.page, inboxItem(), shown, 'Message Inbox: line breaks show')
      await filterBy(recipient.page, SENDER)
      await lineCheck(recipient.page, inboxItem(), shown, `Inbox filtered to ${SENDER}: line breaks show`)

      // 4. Recipient: Chatterbox mini messages (desktop; needs the Messages nodelet out of the sidebar).
      if (desktop) {
        await msg.setNodelets(recipient.page, [msg.NODELETS.chatterbox])
        await recipient.page.goto('/')
        const mini = recipient.page.locator('#chatterbox .message-list-content', { hasText: `newline check ${stamp}` }).first()
        await lineCheck(recipient.page, mini, shown, 'Chatterbox mini messages: line breaks show')
        // Reply from the Chatterbox itself: its own message dialog and send path.
        await demo.step(recipient.page, 'replies from the Chatterbox, over three lines')
        await msg.replyTo(recipient.page, mini, chatReply, { expectTo: SENDER })
        await msg.setNodelets(recipient.page, [msg.NODELETS.messages, msg.NODELETS.chatterbox])
      }

      // 5. Recipient replies over two lines through the reply dialog; the sender sees it.
      await recipient.page.goto('/title/Message+Inbox')
      await demo.step(recipient.page, 'replies from the Inbox, over two lines')
      await msg.replyTo(recipient.page, inboxItem(), reply, { expectTo: SENDER })
      await sender.page.reload()
      const senderTexts = await msg.messageTexts(sender)
      await lineCheck(sender.page, senderTexts.filter({ hasText: `Inbox reply ${stamp}` }).first(), reply.join('\n'),
        'the Inbox reply arrives with its line breaks')
      if (desktop) {
        await lineCheck(sender.page, senderTexts.filter({ hasText: `Chatterbox reply ${stamp}` }).first(), chatReply.join('\n'),
          'the Chatterbox reply arrives with its line breaks')
      }

      // Chatterlight: the full-page chat. Its header Messages box shows the reply, and a
      // multi-line message composed there arrives intact.
      if (sender.device === 'mobile') await sender.page.keyboard.press('Escape')
      await sender.page.goto('/title/chatterlight')
      const header = sender.page.locator('.chatterlight__header-nodelet .message-list-content', { hasText: `Inbox reply ${stamp}` }).first()
      await lineCheck(sender.page, header, reply.join('\n'), 'Chatterlight: the reply shows with its line breaks')
      await demo.step(sender.page, `writes ${RECIPIENT} from Chatterlight, over three lines`)
      await msg.sendMessage(sender, RECIPIENT, fromChatterlight, { from: 'chatterlight' })
      await recipient.page.goto('/')
      const fromCl = (await msg.messageTexts(recipient)).filter({ hasText: `From Chatterlight ${stamp}` }).first()
      await lineCheck(recipient.page, fromCl, fromChatterlight.join('\n'), 'the Chatterlight message arrives with its line breaks')
      if (recipient.device === 'mobile') await recipient.page.keyboard.press('Escape')

      // 6. Sender: Sent, then filtered by recipient (#4701).
      await sender.page.goto('/title/Message+Inbox')
      await demo.click(sender.page.locator('.message-inbox-tab', { hasText: 'Sent' }))
      const sentItem = () => sender.page.locator('.message-inbox .message-inbox-sent-text', { hasText: `newline check ${stamp}` }).first()
      await lineCheck(sender.page, sentItem(), shown, 'Sent: line breaks show', { contains: true })
      await filterBy(sender.page, RECIPIENT)
      await lineCheck(sender.page, sentItem(), shown, `Sent filtered to ${RECIPIENT}: line breaks show`, { contains: true })

      // The Message Outbox page: Message Inbox opened straight on Sent.
      await sender.page.goto('/title/Message+Outbox')
      await expect(sender.page.locator('.message-inbox-tab--active')).toContainText('Sent')
      await lineCheck(sender.page, sentItem(), shown, 'Message Outbox: line breaks show', { contains: true })
      await lineCheck(sender.page,
        sender.page.locator('.message-inbox .message-inbox-sent-text', { hasText: `From Chatterlight ${stamp}` }).first(),
        fromChatterlight.join('\n'), 'Message Outbox: the Chatterlight message too', { contains: true })

      // 7. Recipient archives it; the Archived view shows it the same way.
      await recipient.page.goto('/title/Message+Inbox')
      await demo.step(recipient.page, 'archives the message')
      const item = inboxItem().locator('xpath=ancestor::*[.//button[contains(@class,"message-list-action-btn--archive")]][1]')
      const archived = recipient.page.waitForResponse((r) => /\/api\/messages\/\d+\/action\/archive/.test(r.url()))
      await demo.click(item.locator('button[title="Archive message"]').first())
      expect((await archived).status()).toBe(200)
      const archivedToggle = recipient.page.locator('.message-inbox-archive-toggle button', { hasText: /^Archived/ })
      await expect(archivedToggle).not.toHaveText(/\(0\)/, { timeout: 10000 })
      await demo.click(archivedToggle)
      await lineCheck(recipient.page, inboxItem(), shown, 'Archived: line breaks show')

      // 8. /msg from the Chatterbox (one line) still arrives intact (desktop).
      if (desktop) {
        await sender.page.goto('/')
        await demo.step(sender.page, `sends /msg ${RECIPIENT} from the Chatterbox`)
        await msg.msgFromChatterbox(sender.page, RECIPIENT, `one-line chatterbox note ${stamp}`)
        await recipient.page.goto('/')
        await lineCheck(recipient.page, recipient.page.locator('#messages .message-list-content', { hasText: `chatterbox note ${stamp}` }).first(),
          `one-line chatterbox note ${stamp}`, 'the Chatterbox /msg arrives intact')
      }
    }, { cleanup })
  })

  test('usergroup messages keep their line breaks in the inbox, the archive and reply-all', async ({ browser }) => {
    const stamp = Date.now().toString(36)
    const lines = [`Group newline check ${stamp}`, 'second line for the archive']
    const replyAll = [`Group reply ${stamp}`, 'reply-all, also two lines']
    const member = await demo.actor(browser, 'genericdev (edev member)', '#38495e')
    const { page } = member
    let before

    await demo.scenario('message-newlines-group', [member], async () => {
      await loginAs(page, 'genericdev', 'blah')
      before = await msg.getNodelets(page)
      await msg.setNodelets(page, [msg.NODELETS.messages, ...before.filter((id) => id !== msg.NODELETS.messages)])
      await page.reload()

      await demo.step(page, 'writes the edev group a message over two lines')
      await msg.sendMessage(member, 'edev', lines)

      // The sender is a member, so their own Inbox gets the group copy.
      await page.goto('/title/Message+Inbox')
      const own = page.locator('.message-inbox .message-list-content', { hasText: `newline check ${stamp}` }).first()
      await lineCheck(page, own, lines.join('\n'), 'own Inbox (to group: edev): line breaks show')

      await demo.step(page, 'replies to all of edev, over two lines')
      await msg.replyTo(page, own, replyAll, { all: true, expectTo: 'edev' })

      // Sent, filtered to the edev group (#4701).
      await page.goto('/title/Message+Inbox')
      await demo.click(page.locator('.message-inbox-tab', { hasText: 'Sent' }))
      await demo.click(page.locator('.message-inbox-filters-toggle'))
      const groupSelect = page.locator('.message-inbox-filter-group', { hasText: 'Sent to Usergroup' }).locator('select')
      await groupSelect.selectOption({ label: 'edev' })
      await expect(page.locator('.message-inbox-filter-chip', { hasText: 'edev' })).toBeVisible({ timeout: 10000 })
      await lineCheck(page, page.locator('.message-inbox .message-inbox-sent-text', { hasText: `newline check ${stamp}` }).first(),
        lines.join('\n'), 'Sent filtered to edev: line breaks show', { contains: true })

      await page.goto('/title/usergroup+message+archive?viewgroup=edev')
      await lineCheck(page, page.locator('td.usergroup-archive__td', { hasText: `newline check ${stamp}` }).first(),
        lines.join('\n'), 'archive: the message keeps its line breaks')
      await lineCheck(page, page.locator('td.usergroup-archive__td', { hasText: `Group reply ${stamp}` }).first(),
        replyAll.join('\n'), 'archive: the reply-all keeps its line breaks')
    }, { cleanup: async () => { if (before) await msg.setNodelets(page, before).catch(() => {}) } })
  })
})
