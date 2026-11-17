/**
 * Where a user's notifications are on screen, by device.
 *
 *   desktop: the Notifications nodelet in the sidebar (#notifications)
 *   mobile:  the bottom nav's "Notify" button (with a count badge), which opens a
 *            drawer listing them (.mobile-notifications-content)
 *
 *   const n = notificationsUI(actor)        // actor from fixtures/demo.js
 *   await n.open()                          // no-op on desktop; opens the drawer on mobile
 *   const entry = n.entries.filter({ hasText: '...' })
 *   await n.close()
 *
 * The desktop nodelet only renders if the user has it in their nodelet list; specs
 * add it via POST /api/nodelets (see discussion-reply-notification.spec.js).
 */
const demo = require('./demo')

function notificationsUI(actor) {
  const { page } = actor
  if (actor.device === 'mobile') {
    const button = page.locator('.mobile-bottom-nav button', { hasText: 'Notify' })
    const drawer = page.locator('.mobile-modal-drawer')
    return {
      handle: button,
      panel: page.locator('.mobile-notifications-content'),
      entries: page.locator('.mobile-notifications-list-item'),
      async open() {
        await demo.click(button)
        await drawer.waitFor({ state: 'visible' })
        await page.locator('.mobile-modal-loading').waitFor({ state: 'detached' }).catch(() => {})
      },
      async close() {
        if (await drawer.isVisible()) await page.locator('.mobile-modal-close-btn').click()
      },
    }
  }
  const nodelet = page.locator('#notifications')
  return {
    handle: nodelet,
    panel: nodelet,
    entries: page.locator('#notifications_list li'),
    async open() { await nodelet.waitFor({ state: 'visible' }) },
    async close() {},
  }
}

module.exports = { notificationsUI }
