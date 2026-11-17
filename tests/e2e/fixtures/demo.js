/**
 * Demo recording for multi-user E2E specs.
 *
 * Normally these helpers are near no-ops, so a spec that uses them runs as an
 * ordinary headless test. With E2E_DEMO=1 (see tools/e2e-demo.sh):
 *   - each actor's browser context records its own video;
 *   - every page carries a banner naming the actor and the current step;
 *   - show()/click() scroll the element to the middle of the screen and outline it,
 *     and steps pause so a person can follow;
 *   - a failing scenario turns every banner red with the error and holds on it;
 *   - the actors' videos are stitched side by side into e2e-demos/<name>.mp4,
 *     and every show() also saves a numbered still to e2e-demos/<name>/.
 *
 * Mobile: E2E_DEMO_DEVICE=mobile (or { device: 'mobile' } on one actor) runs that
 * actor as a phone (Pixel 7: 412x839 CSS px, touch, mobile UA) at that resolution.
 *
 * Work the harness does outside the browser (a shell command such as a tools/ script,
 * or setup in an unrecorded session) is shown as an amber TEST HARNESS card, so the
 * video never hides a step: demo.shell() for commands, demo.note() for anything else.
 *
 * The assertions in the spec are the proof; the video is a way to watch it happen.
 *
 *   await demo.scenario('my-feature', [alice, bob], async () => { ... })
 */
const fs = require('fs')
const path = require('path')
const { execFileSync, execSync } = require('child_process')
const { devices } = require('@playwright/test')

const DEMO = !!process.env.E2E_DEMO
const PAUSE_MS = Number(process.env.E2E_DEMO_PAUSE || 1500)
const DESKTOP = { width: 900, height: 760 }
const MOBILE_DEVICE = 'Pixel 7'
const DEFAULT_DEVICE = process.env.E2E_DEMO_DEVICE || 'desktop'
// Output lives outside test-results/, which Playwright empties at the start of every run.
const DEMO_DIR = 'e2e-demos'
let current = { name: null, shot: 0 }
const CAPTION_KEY = '__e2e_demo_caption'
const STATE_KEY = '__e2e_demo_state'

// Runs in the page on every navigation: draw the banner from sessionStorage.
function bannerScript({ label, color, captionKey, stateKey }) {
  const draw = () => {
    let bar = document.getElementById('__e2e_demo_bar')
    if (!bar) {
      bar = document.createElement('div')
      bar.id = '__e2e_demo_bar'
      bar.style.cssText = [
        'position:fixed', 'left:0', 'right:0', 'bottom:0', 'z-index:2147483647',
        'font:600 15px/1.35 system-ui,sans-serif', 'color:#fff', 'padding:8px 12px',
        'box-shadow:0 -2px 8px rgba(0,0,0,.35)', 'pointer-events:none', 'white-space:pre-wrap',
      ].join(';')
      document.documentElement.appendChild(bar)
    }
    let caption = ''
    let state = ''
    try {
      caption = sessionStorage.getItem(captionKey) || ''
      state = sessionStorage.getItem(stateKey) || ''
    } catch (e) { /* no storage */ }
    bar.style.background = state === 'failed' ? '#b3261e' : state === 'passed' ? '#1e7a3c' : color
    bar.textContent = `${label}${caption ? ' — ' + caption : ''}`
  }
  window.__e2eDemoDraw = draw
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', draw)
  } else {
    draw()
  }
}

function rawVideoDir() {
  return path.join('test-results', 'demo-raw', String(process.pid))
}

function contextOptions(device) {
  if (device === 'mobile') {
    const { defaultBrowserType, ...phone } = devices[MOBILE_DEVICE]   // eslint-disable-line no-unused-vars
    return phone
  }
  return DEMO ? { viewport: DESKTOP } : {}
}

/**
 * A fresh browser context (independent session) for one actor.
 * opts.device: 'desktop' | 'mobile' (default: E2E_DEMO_DEVICE, else desktop). Mobile
 * applies in plain runs too, so a spec can assert mobile layout without recording.
 */
async function actor(browser, label, color = '#38495e', opts = {}) {
  const device = opts.device || DEFAULT_DEVICE
  const options = contextOptions(device)
  if (DEMO) options.recordVideo = { dir: rawVideoDir(), size: options.viewport }
  const ctx = await browser.newContext(options)
  if (DEMO) await ctx.addInitScript(bannerScript, { label, color, captionKey: CAPTION_KEY, stateKey: STATE_KEY })
  const page = await ctx.newPage()
  return { ctx, page, label, device }
}

/** Save a still of the page as it looks now (demo mode only). */
async function snap(page, label = 'shot') {
  if (!DEMO || !current.name) return null
  const dir = path.join(DEMO_DIR, current.name)
  fs.mkdirSync(dir, { recursive: true })
  current.shot += 1
  const file = path.join(dir, `${String(current.shot).padStart(2, '0')}-${label.replace(/[^a-z0-9]+/gi, '-').toLowerCase()}.png`)
  await page.screenshot({ path: file }).catch(() => {})
  return file
}

async function setBanner(page, caption, state) {
  await page.evaluate(([ck, sk, c, s]) => {
    try {
      if (c !== null) sessionStorage.setItem(ck, c)
      if (s !== null) sessionStorage.setItem(sk, s)
    } catch (e) { /* no storage */ }
    if (window.__e2eDemoDraw) window.__e2eDemoDraw()
  }, [CAPTION_KEY, STATE_KEY, caption, state]).catch(() => {})
}

/** Set the step caption on an actor's page (persists across navigations). */
async function step(page, text) {
  if (!DEMO) return
  await setBanner(page, text, null)
  await page.waitForTimeout(PAUSE_MS)
}

/**
 * Bring an element on screen: scroll it to the middle of the viewport (visibly, not
 * a jump) and outline it for a moment. Use it on every result a viewer must see --
 * a notification, a new reply, a message -- even if it might already be in view.
 */
async function show(locator, ms = 1200, { still = true } = {}) {
  if (!DEMO) return
  const page = locator.page()
  await locator.first().waitFor({ state: 'visible', timeout: 10000 })   // fail fast, never hang
  await locator.first().evaluate(el => el.scrollIntoView({ behavior: 'smooth', block: 'center' }))
  await page.waitForTimeout(700)
  await locator.first().evaluate((el, dur) => {
    const prev = [el.style.outline, el.style.outlineOffset]
    el.style.outline = '4px solid #e8402c'
    el.style.outlineOffset = '2px'
    setTimeout(() => { [el.style.outline, el.style.outlineOffset] = prev }, dur)
  }, ms)
  if (still) await snap(page, (await page.evaluate(k => sessionStorage.getItem(k), CAPTION_KEY).catch(() => '')) || 'result')
  await page.waitForTimeout(ms)
}

// Bounded like show(): with no action timeout a missing element waits out the whole
// test, and a test that times out never gets to run its cleanup.
async function click(locator) {
  await show(locator, 900, { still: false })
  await locator.click({ timeout: 10000 })
}

/**
 * A TEST HARNESS card over each actor's page: something the test did outside the browser.
 * title says what it was for; detail can carry the command and what came back. Held long
 * enough to read, then removed. No-op outside demo mode.
 */
async function note(actors, title, detail = '') {
  if (!DEMO) return
  const list = [].concat(actors || []).filter(Boolean)
  if (!list.length) return
  await Promise.all(list.map(a => a.page.evaluate(([t, d]) => {
    const old = document.getElementById('__e2e_demo_card')
    if (old) old.remove()
    const card = document.createElement('div')
    card.id = '__e2e_demo_card'
    card.style.cssText = [
      'position:fixed', 'left:50%', 'top:42%', 'transform:translate(-50%,-50%)', 'z-index:2147483647',
      'width:min(92vw,640px)', 'box-sizing:border-box', 'background:#fff8e6', 'color:#3d2a00',
      'border:3px solid #c77c00', 'border-radius:10px', 'box-shadow:0 8px 30px rgba(0,0,0,.45)',
      'padding:14px 16px', 'font:15px/1.4 system-ui,sans-serif', 'pointer-events:none',
    ].join(';')
    const head = document.createElement('div')
    head.textContent = 'TEST HARNESS · outside the browser'
    head.style.cssText = 'font-weight:700;font-size:12px;letter-spacing:.06em;color:#c77c00;margin-bottom:6px'
    const body = document.createElement('div')
    body.textContent = t
    body.style.cssText = 'font-weight:600;margin-bottom:' + (d ? '8px' : '0')
    card.appendChild(head)
    card.appendChild(body)
    if (d) {
      const pre = document.createElement('pre')
      pre.textContent = d
      pre.style.cssText = 'margin:0;white-space:pre-wrap;word-break:break-all;font:12px/1.4 ui-monospace,monospace;background:#2b2b2b;color:#f5f5f5;padding:8px;border-radius:6px'
      card.appendChild(pre)
    }
    document.documentElement.appendChild(card)
  }, [title, detail]).catch(() => {})))
  await list[0].page.waitForTimeout(Math.max(PAUSE_MS * 2, 3000))
  await snap(list[0].page, `harness ${title}`)
  await Promise.all(list.map(a => a.page.evaluate(() => {
    const c = document.getElementById('__e2e_demo_card')
    if (c) c.remove()
  }).catch(() => {})))
}

/**
 * Run a shell command for the test (e.g. `docker exec e2devapp perl /var/everything/tools/...`)
 * and show it on the recording as a TEST HARNESS card. Use this rather than execSync in demo
 * specs, so every harness step is visible. purpose: what it's for, in plain words.
 * opts.result(stdout): one line saying what came back. Returns stdout; throws if it fails.
 */
async function shell(actors, command, purpose, { result } = {}) {
  let out
  try {
    out = execSync(command, { encoding: 'utf8' })
  } catch (err) {
    await note(actors, `${purpose} (FAILED)`, `$ ${command}\n${String(err.stderr || err.message || err).trim().split('\n').slice(-3).join('\n')}`)
    throw err
  }
  const summary = result ? result(out) : ''
  await note(actors, purpose, `$ ${command}${summary ? `\n→ ${summary}` : ''}`)
  return out
}

/** Short pause in demo mode only (e.g. to let a viewer read a result). */
async function linger(page, ms = PAUSE_MS) {
  if (DEMO) await page.waitForTimeout(ms)
}

function duration(file) {
  const out = execFileSync('ffprobe', ['-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', file])
  return parseFloat(String(out)) || 0
}

/**
 * Close every actor's context and, in demo mode, stitch their videos left-to-right
 * into e2e-demos/<name>.mp4. Shorter videos hold their last frame.
 */
async function finishDemo(actors, name) {
  const pages = actors.map(a => a.page)
  await Promise.all(actors.map(a => a.ctx.close().catch(() => {})))
  if (!DEMO) return null

  const videos = []
  for (const p of pages) {
    const v = p.video()
    if (v) videos.push(await v.path())
  }
  if (!videos.length) return null
  const outDir = DEMO_DIR
  fs.mkdirSync(outDir, { recursive: true })
  const out = path.join(outDir, `${name}.mp4`)
  const longest = Math.max(...videos.map(duration))
  const inputs = videos.flatMap(v => ['-i', v])
  const tallest = Math.max(...actors.map(a => (contextOptions(a.device).viewport || DESKTOP).height))
  const height = tallest + (tallest % 2)   // x264/yuv420p needs even dimensions
  const padded = videos.map((_, i) =>
    `[${i}:v]scale=-2:${height},tpad=stop_mode=clone:stop_duration=${Math.ceil(longest) + 1}[p${i}]`)
  const stack = videos.length > 1
    ? `${padded.join(';')};${videos.map((_, i) => `[p${i}]`).join('')}hstack=inputs=${videos.length}[v]`
    : `${padded[0]};[p0]null[v]`
  execFileSync('ffmpeg', ['-y', '-loglevel', 'error', ...inputs, '-filter_complex', stack, '-map', '[v]',
    '-t', String(longest), '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-preset', 'veryfast', '-crf', '26', out])
  return out
}

/**
 * Run a multi-actor scenario. On success every banner turns green; on failure every
 * banner turns red with the error and holds, so the video ends on what went wrong.
 * Always closes the contexts and (in demo mode) writes the video, then rethrows.
 */
async function scenario(name, actors, fn, { cleanup } = {}) {
  let failure
  const device = [...new Set(actors.map(a => a.device))].join('+')
  name = device === 'desktop' ? name : `${name}-${device}`
  current = { name, shot: 0 }
  if (DEMO) fs.rmSync(path.join(DEMO_DIR, name), { recursive: true, force: true })
  try {
    await fn()
    if (DEMO) {
      await Promise.all(actors.map(a => setBanner(a.page, 'PASSED', 'passed')))
      await linger(actors[0].page, 2500)
    }
  } catch (err) {
    failure = err
    if (DEMO) {
      const msg = String(err && err.message || err).split('\n').find(l => l.trim()) || 'error'
      await Promise.all(actors.map(a => setBanner(a.page, `FAILED: ${msg.replace(/\u001b\[[0-9;]*m/g, '').slice(0, 160)}`, 'failed')))
      await linger(actors[0].page, 4000)
    }
  } finally {
    if (cleanup) await cleanup().catch(() => {})
    // A stitching problem must never hide the test's own result.
    const video = await finishDemo(actors, name).catch(err => {
      console.warn(`demo video could not be written: ${String(err.message || err).split('\n')[0]}`)
      return null
    })
    if (video) console.log(`demo video: ${video}`)
  }
  if (failure) throw failure
}

module.exports = { DEMO, actor, step, show, highlight: show, snap, click, linger, note, shell, scenario, finishDemo }
