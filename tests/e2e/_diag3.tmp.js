const { chromium } = require('@playwright/test');
const { loginAsE2EAdmin } = require('./fixtures/auth');
(async () => {
  const b = await chromium.launch(); const ctx = await b.newContext(); const p = await ctx.newPage();
  await loginAsE2EAdmin(p);
  const u = await p.evaluate(() => window.e2 && window.e2.user);
  console.log('  window.e2.user keys:', Object.keys(u||{}).join(', '));
  console.log('  title/name field:', JSON.stringify({title:u.title, name:u.name, user:u.user, guest:u.guest}));
  await b.close();
})().catch(e=>{console.log('ERR', e.message)});
