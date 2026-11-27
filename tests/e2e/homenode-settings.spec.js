const { test, expect } = require('@playwright/test')
const demo = require('./fixtures/demo')
const { loginAs } = require('./fixtures/auth')

/**
 * Homenode settings (#4659): a member hides their usergroups and categories from other members, and
 * their daily votes and C!s from their own homenode, in Settings > Advanced.
 *
 * Users: normaluser22 (the member) and normaluser23 (someone else), both pw "blah"; no other spec
 * touches their preferences. Setup (harness): an ordinary usergroup with normaluser22 in it, and a
 * category normaluser22 maintains. normaluser23 first sees both on normaluser22's homenode; after
 * normaluser22 ticks the settings, normaluser23 sees neither, while normaluser22 still sees both on
 * their own homenode and no longer sees their daily votes and C!s. Cleanup turns the settings off and
 * removes the planted nodes. Setup also makes normaluser22's writeup count due for its hourly refresh,
 * so normaluser23's first view is the request that saves normaluser22's settings (#4751).
 * Watch: `./tools/e2e-demo.sh homenode-settings`.
 */
test('a member hides their usergroups, categories and daily votes from their homenode', async ({ browser }) => {
  test.setTimeout(demo.DEMO ? 240000 : 90000)
  const member = await demo.actor(browser, 'normaluser22 (the member)', '#38495e')
  const other = await demo.actor(browser, 'normaluser23 (another member)', '#2f6f8f')
  const stamp = Date.now()
  const group = `Homenode club ${stamp}`
  const category = `Homenode shelf ${stamp}`
  const homenode = '/user/normaluser22'
  const SETTINGS = ['hidehomenodeUG', 'hidehomenodeUC', 'hidevotedata']

  const perl = (code) =>
    `docker exec e2devapp perl -I/var/everything/ecore -I/var/libraries/lib/perl5 -MEverything -e '${code}'`
  const resetVars =
    'my $u = $DB->getNodeById($DB->getNode("normaluser22", "user")->{node_id}, "force"); my $v = Everything::getVars($u); ' +
    `$v->{$_} = 0 for qw(${SETTINGS.join(' ')}); Everything::setVars($u, $v); $DB->updateNode($u, -1);`

  const memberOf = (page) => page.locator('dt:has-text("member of") + dd')
  const categories = (page) => page.locator('dt:has-text("categories maintained") + dd')
  const daily = (page) => page.locator('.user-display__daily-votes')

  const cleanup = async () => {
    await demo.shell(
      member,
      perl(
        'initEverything("development-docker"); ' + resetVars + ' ' +
          `for my $t ("${group}", "${category}") { my $id = $DB->sqlSelect("node_id", "node", "title=" . $DB->quote($t)) or next; ` +
          '$DB->nukeNode($DB->getNodeById($id, "force"), -1, 1); $DB->sqlDelete("tomb", "node_id=$id") }'
      ),
      'turns the settings off and removes the test usergroup and category'
    )
  }

  await demo.scenario('homenode-settings', [member, other], async () => {
    await demo.shell(
      member,
      perl(
        'initEverything("development-docker"); ' + resetVars + ' ' +
          '$v->{nwriteupsupdate} = 1; Everything::setVars($u, $v); ' +
          'my $root = $DB->getNode("root", "user"); my $me = $DB->getNode("normaluser22", "user"); ' +
          `my $g = $DB->insertNode("${group}", "usergroup", $root, {}, "skip maintenance"); ` +
          '$DB->insertIntoNodegroup($DB->getNodeById($g, "force"), -1, $me->{node_id}); ' +
          `$DB->insertNode("${category}", "category", $me, { author_user => $me->{node_id} }, "skip maintenance"); print "ok"`
      ),
      `puts normaluser22 in "${group}" and gives them the category "${category}"`,
      { result: (o) => o.trim() }
    )

    await Promise.all([loginAs(member.page, 'normaluser22', 'blah'), loginAs(other.page, 'normaluser23', 'blah')])

    await other.page.goto(homenode)
    await expect(memberOf(other.page)).toContainText(group, { timeout: 10000 })
    await expect(categories(other.page)).toContainText(category)
    await demo.step(other.page, "opens normaluser22's homenode: their usergroup and category are listed")
    await demo.show(memberOf(other.page))

    await member.page.goto(homenode)
    await expect(daily(member.page)).toContainText('votes', { timeout: 10000 })
    await demo.step(member.page, 'opens their own homenode: their daily votes and C!s are shown')
    await demo.show(daily(member.page))

    await member.page.goto('/title/Settings#advanced')
    const labels = [
      "I'm a loner, Dottie, a rebel.",
      "I'm a secret librarian.",
      "I'm careless with my votes and C!s",
    ]
    for (const text of labels) {
      const label = member.page.locator(`label:has(strong:text("${text}"))`)
      await expect(label).toBeVisible({ timeout: 10000 })
      await demo.click(label)
      await expect(label.locator('input[type="checkbox"]')).toBeChecked()
    }
    await demo.step(member.page, "in Settings > Advanced, ticks: don't list my usergroups, my categories, or my votes and C!s")
    await demo.click(member.page.locator('button:has-text("Save Changes"):not([disabled])'))
    await expect(member.page.locator('button:has-text("Save Changes")[disabled]')).toBeVisible({ timeout: 10000 })
    await demo.step(member.page, 'saves')

    await other.page.reload()
    await expect(other.page.locator('h1', { hasText: 'normaluser22' }).first()).toBeVisible({ timeout: 10000 })
    await expect(other.page.locator('body')).not.toContainText(group)
    await expect(other.page.locator('body')).not.toContainText(category)
    await demo.step(other.page, "reloads normaluser22's homenode: the usergroup and category are no longer listed")
    await demo.show(other.page.locator('h1', { hasText: 'normaluser22' }).first())

    await member.page.goto(homenode)
    await expect(memberOf(member.page)).toContainText(group, { timeout: 10000 })
    await expect(categories(member.page)).toContainText(category)
    await expect(daily(member.page)).toHaveCount(0)
    await demo.step(member.page, 'their own homenode still lists both, and no longer shows their daily votes and C!s')
    await demo.show(memberOf(member.page))
  }, { cleanup })
})
