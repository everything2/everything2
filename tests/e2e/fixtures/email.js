/**
 * Emails in e2e specs. Development sends no mail: node2mail keeps each message in the dev
 * mail spool, and tools/test-password-reset.pl --sent <user> prints the newest one sent to
 * that user with the link in it (pointed at http://localhost:9080). Specs read mail only
 * through that tool, via demo.shell, so the recording shows a TEST HARNESS card for it.
 */
const demo = require('./demo')

/** The newest email sent to uname: { to, subject, link, raw }. who: actor(s) to show the card on. */
async function sentEmail(who, uname) {
  const parse = (out) => ({
    to: (out.match(/^To: (.*)$/m) || [])[1] || '',
    subject: (out.match(/^Subject: (.*)$/m) || [])[1] || '',
    link: (out.match(/^(http:\/\/localhost:9080\/node\/superdoc\/Confirm\+password\?\S+)$/m) || [])[1] || '',
  })
  const out = await demo.shell(
    who,
    `docker exec e2devapp perl /var/everything/tools/test-password-reset.pl --sent ${uname}`,
    `reads the email sent to ${uname} (dev keeps outgoing mail in a spool instead of sending it)`,
    { result: (o) => { const m = parse(o); return `"${m.subject}" to ${m.to}, link ${m.link ? 'found' : 'MISSING'}` } }
  )
  return { ...parse(out), raw: out }
}

module.exports = { sentEmail }
