const { test, expect } = require('@playwright/test')
const demo = require('./fixtures/demo')
const { loginAs } = require('./fixtures/auth')
const { createWriteup } = require('./fixtures/content')

/**
 * Bookmark notifications (#4732): when a member bookmarks a node, Cool Man Eddie tells the authors
 * who bookmarked it, unless the bookmarker ticked "but do it anonymously" in Settings > Advanced.
 *
 * Users: normaluser28 (bookmarks) and normaluser29 (the author), both pw "blah"; no other spec touches
 * their preferences. Setup (harness): normaluser29 publishes a writeup. normaluser28 bookmarks its
 * e2node and normaluser29's Message Inbox names them; normaluser28 then turns on "but do it
 * anonymously", bookmarks it again, and the new message doesn't name them. Cleanup resets both
 * members' bookmark settings, deletes the messages and removes the writeup.
 * Watch: `./tools/e2e-demo.sh anonymous-bookmark`.
 */
test('a member bookmarks a node, then bookmarks it anonymously', async ({ browser }) => {
  test.setTimeout(demo.DEMO ? 240000 : 90000)
  const bookmarker = await demo.actor(browser, 'normaluser28 (bookmarks)', '#38495e')
  const author = await demo.actor(browser, 'normaluser29 (the author)', '#2f6f8f')
  const stamp = Date.now()
  const title = `Bookmark me ${stamp}`
  const VARS = ['anonymous_bookmark', 'no_bookmarkinformer', 'no_bookmarknotification']
  let e2nodeId

  const perl = (code) =>
    `docker exec e2devapp perl -I/var/everything/ecore -I/var/libraries/lib/perl5 -MEverything -e '${code}'`
  const resetVars =
    'for my $n ("normaluser28", "normaluser29") { my $u = $DB->getNodeById($DB->getNode($n, "user")->{node_id}, "force"); ' +
    `my $v = Everything::getVars($u); $v->{$_} = 0 for qw(${VARS.join(' ')}); Everything::setVars($u, $v); $DB->updateNode($u, -1) }`

  const inboxItems = (page) => page.locator('.message-inbox .message-list-content', { hasText: title })
  const bookmarkButton = (page) => page.locator('.e2-action-chip', { hasText: /^Bookmark/ }).first()

  const cleanup = async () => {
    await demo.shell(
      author,
      perl(
        'initEverything("development-docker"); ' + resetVars + '; ' +
          `$DB->sqlDelete("message", "msgtext LIKE " . $DB->quote("%${title}%")); ` +
          `for my $id (map { $_->[0] } @{ $DB->{dbh}->selectall_arrayref("SELECT node_id FROM node WHERE title LIKE " . $DB->quote("${title}%")) }) { ` +
          '$DB->sqlDelete("links", "to_node=$id"); my $n = $DB->getNodeById($id, "force") or next; $DB->nukeNode($n, -1, 1); $DB->sqlDelete("tomb", "node_id=$id") }'
      ),
      'resets both members\' bookmark settings and removes the writeup and its messages'
    )
  }

  const bookmark = async (caption) => {
    await bookmarker.page.goto(`/node/${e2nodeId}`)
    const button = bookmarkButton(bookmarker.page)
    await expect(button).toHaveText('Bookmark', { timeout: 10000 })
    await demo.step(bookmarker.page, caption)
    await demo.click(button)
    await expect(button).toHaveText('Bookmarked', { timeout: 10000 })
  }

  await demo.scenario('anonymous-bookmark', [bookmarker, author], async () => {
    await demo.shell(author, perl('initEverything("development-docker"); ' + resetVars + '; print "ok"'),
      'turns on bookmark messages for both members', { result: (o) => o.trim() })

    await Promise.all([loginAs(bookmarker.page, 'normaluser28', 'blah'), loginAs(author.page, 'normaluser29', 'blah')])
    ;({ e2nodeId } = await createWriteup(author.page, { title }))
    await demo.note(author, 'TEST HARNESS', `normaluser29 publishes the writeup "${title}"`)

    // 1. A plain bookmark names the bookmarker.
    await bookmark(`bookmarks "${title}"`)
    await author.page.goto('/title/Message+Inbox')
    await expect(inboxItems(author.page).first()).toContainText('was bookmarked by normaluser28', { timeout: 10000 })
    await demo.step(author.page, 'Message Inbox: Cool Man Eddie says normaluser28 bookmarked it')
    await demo.show(inboxItems(author.page).first())

    // 2. Unbookmark, turn on "but do it anonymously", bookmark again.
    await demo.click(bookmarkButton(bookmarker.page))
    await expect(bookmarkButton(bookmarker.page)).toHaveText('Bookmark', { timeout: 10000 })
    await bookmarker.page.goto('/title/Settings#advanced')
    const anon = bookmarker.page.locator('label:has(strong:text("but do it anonymously"))')
    await expect(anon).toBeVisible({ timeout: 10000 })
    await demo.step(bookmarker.page, 'removes the bookmark, then in Settings > Advanced ticks "but do it anonymously"')
    await demo.click(anon)
    await expect(anon.locator('input[type="checkbox"]')).toBeChecked()
    await demo.click(bookmarker.page.locator('button:has-text("Save Changes"):not([disabled])'))
    await expect(bookmarker.page.locator('button:has-text("Save Changes")[disabled]')).toBeVisible({ timeout: 10000 })
    await bookmark(`bookmarks "${title}" again`)

    await author.page.reload()
    await expect(inboxItems(author.page)).toHaveCount(2, { timeout: 10000 })
    const newest = inboxItems(author.page).first()
    await expect(newest).toContainText('was bookmarked. Dig it, baby.')
    await expect(newest).not.toContainText('normaluser28')
    await expect(inboxItems(author.page).nth(1)).toContainText('was bookmarked by normaluser28')
    await demo.step(author.page, "Message Inbox: the new message doesn't say who bookmarked it")
    await demo.show(newest)
  }, { cleanup })
})
