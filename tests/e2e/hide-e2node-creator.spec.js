const { test, expect } = require('@playwright/test')
const demo = require('./fixtures/demo')
const { loginAs } = require('./fixtures/auth')

/**
 * "Show who created a writeup page title (a.k.a. e2node)" (#4733): a member unticks it in
 * Settings > Advanced and e2node pages stop showing "created by"; ticking it again brings it back.
 *
 * User: normaluser24 (pw "blah"); no other spec touches their preferences. Setup (harness): an
 * e2node created by root. Cleanup turns the setting back on and removes the e2node.
 * Watch: `./tools/e2e-demo.sh hide-e2node-creator`.
 */
test('a member hides who created an e2node, then shows it again', async ({ browser }) => {
  test.setTimeout(demo.DEMO ? 180000 : 60000)
  const member = await demo.actor(browser, 'normaluser24', '#38495e')
  const title = `Who made me ${Date.now()}`
  const LABEL = 'Show who created a writeup page title (a.k.a. e2node)'
  let e2nodeId

  const perl = (code) =>
    `docker exec e2devapp perl -I/var/everything/ecore -I/var/libraries/lib/perl5 -MEverything -e '${code}'`
  const resetVar =
    'my $u = $DB->getNodeById($DB->getNode("normaluser24", "user")->{node_id}, "force"); my $v = Everything::getVars($u); ' +
    '$v->{hideauthore2node} = 0; Everything::setVars($u, $v); $DB->updateNode($u, -1);'

  const createdBy = (page) => page.locator('.page-header__createdby')
  const heading = (page) => page.locator('h1.page-header__title', { hasText: title })

  const cleanup = async () => {
    await demo.shell(
      member,
      perl(
        'initEverything("development-docker"); ' + resetVar + ' ' +
          `for my $id (map { $_->[0] } @{ $DB->{dbh}->selectall_arrayref("SELECT node_id FROM node WHERE title LIKE " . $DB->quote("${title}%")) }) { ` +
          'my $n = $DB->getNodeById($id, "force") or next; $DB->nukeNode($n, -1, 1); $DB->sqlDelete("tomb", "node_id=$id") }'
      ),
      'turns the setting back on and removes the test e2node'
    )
  }

  const toggleSetting = async (caption, checked) => {
    await member.page.goto('/title/Settings#advanced')
    const label = member.page.locator(`label:has(strong:text("${LABEL}"))`)
    await expect(label).toBeVisible({ timeout: 10000 })
    await demo.step(member.page, caption)
    await demo.click(label)
    const box = label.locator('input[type="checkbox"]')
    if (checked) await expect(box).toBeChecked()
    else await expect(box).not.toBeChecked()
    await demo.click(member.page.locator('button:has-text("Save Changes"):not([disabled])'))
    await expect(member.page.locator('button:has-text("Save Changes")[disabled]')).toBeVisible({ timeout: 10000 })
  }

  await demo.scenario('hide-e2node-creator', [member], async () => {
    const out = await demo.shell(
      member,
      perl(
        'initEverything("development-docker"); ' + resetVar + ' ' +
          `print $DB->insertNode("${title}", "e2node", $DB->getNode("root", "user"), {}, "skip maintenance")`
      ),
      `creates the e2node "${title}" as root`,
      { result: (o) => `node ${o.trim()}` }
    )
    e2nodeId = out.trim()

    await loginAs(member.page, 'normaluser24', 'blah')
    await member.page.goto(`/node/${e2nodeId}`)
    await expect(heading(member.page)).toBeVisible({ timeout: 10000 })
    await expect(createdBy(member.page)).toContainText('created by root')
    await demo.step(member.page, 'opens the e2node: "created by root" is shown')
    await demo.show(createdBy(member.page))

    await toggleSetting(`in Settings > Advanced, unticks "${LABEL}" and saves`, false)
    await member.page.goto(`/node/${e2nodeId}`)
    await expect(heading(member.page)).toBeVisible({ timeout: 10000 })
    await expect(createdBy(member.page)).toHaveCount(0)
    await expect(member.page.locator('#pageheader')).not.toContainText('created by')
    await demo.step(member.page, 'opens the e2node again: no "created by"')
    await demo.show(heading(member.page))

    await toggleSetting('ticks it again and saves', true)
    await member.page.goto(`/node/${e2nodeId}`)
    await expect(createdBy(member.page)).toContainText('created by root', { timeout: 10000 })
    await demo.step(member.page, 'and "created by root" is back')
    await demo.show(createdBy(member.page))
  }, { cleanup })
})
