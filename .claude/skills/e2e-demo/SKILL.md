---
name: e2e-demo
description: Prove a user-visible E2 change works in the real app and record a watchable MP4 (plus stills, desktop or mobile resolution) for Jay. Write (or reuse) a Playwright spec, single-user by default and one browser per user only for collaboration features, run it on warm dev workers, and record it. Use when finishing any feature enhancement or user-facing bug fix, when certifying multi-user behaviour (notifications, discussions/replies, messages, chatterbox, usergroups, votes/C!s, cross-role permissions), after a security fix to show the affected feature still works, or when asked for a demo video/movie of a browsing path. Dev environment only.
---

# E2E demo: prove it, then show it

Unit tests have repeatedly said "works" for features that were broken in the real app.
#4661 passed a Perl test that used `insertNode(..., skip_maintenance)`, but the first
real browser run showed the replies never appearing. This skill is the bar for certifying a user-visible change. The spec's assertions are the
proof; the video is how Jay checks it without taking our word for it.

## When to use it

| Change | What to produce |
|---|---|
| Feature enhancement / user-facing bug fix (the default) | **One actor**: the user does the thing and sees the result. Video + stills. |
| Collaboration feature (one user's action shows up for another: notifications, replies, messages, chatterbox, usergroups, votes/C!s seen by the author) | One actor per user, side by side. Assert in the *other* user's session. Only here; don't add a second user just for show. |
| Layout or anything a phone user touches (most UI work) | Also record a mobile pass: `E2E_DEMO_DEVICE=mobile`. |
| Security fix | The fix is proven by its Perl/API regression test. Then run (or write) the e2e spec for the **feature the fix touched** to show it still works for legitimate users: a "still works" video. See *Security fixes* below. |
| Pure refactor / no visible change | Run the existing spec for the area if there is one; no new video needed unless asked. |

Do it on the feature branch, before reporting the branch done. Commit the spec with the
feature (`tests/e2e/`); the video stays local (`e2e-demos/` is gitignored).

## What makes the proof count

1. **Use the real entry point.** Drive the UI (or the real `/api/...` route through
   PSGI) for the behaviour under test. API calls are fine for *setup* (opting in,
   creating fixtures). Never set `skip_maintenance` or call internals for the thing
   being proven.
2. **Use warm workers.** Every actor views pages before the action, the way real users
   arrive. Some bugs only show on a long-running app that has already served traffic.
3. **Assert where the user would look,** in their own session, after a reload or
   navigation.
4. **Add negative controls in the same run:** the actor (no self-notification), an
   opted-out member, a non-member, a lower role. A negative only counts if it could
   have failed: show "no self-notification" with a user who *is* opted in (they'd be
   notified if the rule broke), and assert something that proves the panel loaded (the
   earlier notification is still there, count unchanged) rather than only that text is
   absent.
5. **Red before green.** Show the spec failing without the fix, by running it before
   the fix lands or naming the repro that failed. Say which in the report.
6. **Mind role masking.** gods (114) has only root and e2e_admin, and both are admins.
   Admin-only paths can hide member bugs (e.g. `canUpdateNode` = author-or-admin). If
   the feature is for ordinary members, test with non-admin users.

## Writing the spec

Put it in `tests/e2e/<feature>.spec.js`. Template:
`tests/e2e/discussion-reply-notification.spec.js`. Use `tests/e2e/fixtures/demo.js`:

```js
const demo = require('./fixtures/demo')
test.setTimeout(demo.DEMO ? 180000 : 60000)

const alice = await demo.actor(browser, 'root (recipient)', '#38495e')   // one per user
const bob   = await demo.actor(browser, 'e2e_admin (actor)', '#2f6f8f')

await demo.scenario('feature-name', [alice, bob], async () => {
  await Promise.all([loginAsRoot(alice.page), loginAsE2EAdmin(bob.page)])
  await demo.step(bob.page, 'clicks Reply')            // banner caption + pause
  await demo.click(bob.page.locator('.some-button'))   // scroll to it, outline, click
  await expect(result).toContainText('...')             // the proof
  await demo.show(result)                               // scroll it on screen + outline
}, { cleanup })                                         // always runs; restore prefs, delete nodes
```

- `demo.show(locator)` on **every result the viewer must see** (a notification, a new
  reply, a message, an empty nodelet for the negative case). It scrolls the element to
  the middle of the viewport, even if it might already be visible, and outlines it.
  Call it *after* the `expect`, so the video only highlights what was asserted.
- `demo.step(page, text)` before each action, written as what the user does ("reloads
  the page"), not as test jargon.
- A single-user feature is just one `actor`; the stitcher handles one video.
- **Mobile resolution.** `E2E_DEMO_DEVICE=mobile` makes every actor a phone (Pixel 7:
  412x839 CSS px, touch, mobile UA); `demo.actor(browser, label, color, { device: 'mobile' })`
  does it for one actor (e.g. a desktop sender and a phone recipient). It applies in plain
  runs too, so a spec can assert mobile layout without recording. On phones there's
  no sidebar: sign-in is a header button and modal (handled by `loginAs`), and
  notifications, chat and inbox sit behind the bottom nav. Open them the way a phone
  user would. Mobile output gets a `-mobile` suffix, so it doesn't overwrite the
  desktop run.
- **Stills.** Every `show()` also saves a numbered PNG at that device's resolution to
  `e2e-demos/<name>[-mobile]/` (`demo.snap(page, label)` for an extra one).
  Send the key stills along with the video when the result is easy to miss in motion.
- Without `E2E_DEMO` the helpers are no-ops, so the spec doubles as a regression test.
- `scenario()` turns banners green (PASSED) or red with the error (FAILED), holds the
  last frame, closes contexts, runs `cleanup`, and stitches the video.
- Test users: `root`/`genericdev` (pw `blah`); `e2e_admin`, `e2e_editor`, `e2e_user`
  (pw `test123`); `loginAs(page, user, pass)` in `tests/e2e/fixtures/auth.js` works at
  desktop and phone sizes (`tools/seeds.pl` has the full list). Nodelets:
  `GET/POST /api/nodelets`. Match on unique per-run titles (`Date.now()`) so reruns
  don't collide.
- **Notifications on screen:** `notificationsUI(actor)` (`fixtures/notifications.js`)
  is the desktop nodelet or the phone's bottom-nav Notify drawer. Call `open()`, then
  read `entries`/`panel`, so one spec covers both devices.
- **Parallel specs share the dev DB.** `POST /api/preferences/notifications` *replaces*
  the user's whole map, so two specs opting the same user in will clobber each other
  (root is used by `notification-delivery`; e2e_admin's prefs by `notifications-nodelet`).
  Only change preferences for a user no other spec touches, and say so in the spec
  header. After writing a spec, run it alongside the related specs a few times.
- **Cleanup has to really clean up.** Deleting discussions is admin-only, so delete as
  an admin actor, check the DB afterwards for leftovers, and remember that stale
  notifications from leftover nodes will show up in the next video.
- **Bound every wait (about 10s).** There is no global action timeout, so a missing
  element otherwise waits out the whole test. A test that times out is ended before
  `cleanup` can make requests, and its nodes are left behind. `demo.click`/`demo.show`
  are bounded already; give your own `waitForSelector`/`waitFor` a `timeout` too.

## Running and delivering

```bash
./docker/devbuild.sh --skip-tests                                # app code isn't volume-mounted
npx playwright test tests/e2e/<feature>.spec.js --reporter=list  # plain run first
./tools/e2e-demo.sh <feature>                                    # record: e2e-demos/<feature>.mp4
E2E_DEMO_PAUSE=2500 ./tools/e2e-demo.sh <feature>                # slower captions
E2E_DEMO_DEVICE=mobile ./tools/e2e-demo.sh <feature>             # phone resolution: <feature>-mobile.mp4
```

All output is under `e2e-demos/` (gitignored, and `*.mp4`/`*.webm` are ignored
repo-wide). Never commit recordings.

Before sending, check the video yourself with a contact sheet and read the image:

```bash
ffmpeg -v error -y -i e2e-demos/<feature>.mp4 -vf "fps=1/5,scale=720:-1,tile=2x5" -frames:v 1 <scratchpad>/frames.png
```

Confirm that the banners read correctly, each asserted result is on screen and outlined,
and it ends on PASSED. Then send the MP4 with SendUserFile (`display: 'render'`). In the
report, give what the video shows, the red-before-green evidence, and anything the run
does not cover (e.g. "admins only; member path untested").

## Security fixes

- The fix's proof is the Perl/API regression test, named and worded neutrally.
- The e2e/video part only shows the **legitimate feature still working** after the fix.
  Name the spec, captions and scenario after the feature ("discussion reply
  notification"), never after the flaw. No step that demonstrates the attack, no
  "blocked" or "denied" framing that hints at it.
- If an existing spec already covers the feature, rerun it in demo mode rather than
  writing a new one; a new spec committed alongside a security fix can itself point at
  the flaw.
- Videos stay local (SendUserFile only). Never attach them to public issues or PRs.

## Don'ts

- Never run this against production (no creds, and it's prod). Verify prod with curl,
  CloudWatch or the read-only Lambda instead.
- Don't count a passing video as proof if the action under test went through a setup
  shortcut.
- If the run finds a bug, keep the failing video. It's the clearest bug report, so send
  it along with the diagnosis.
