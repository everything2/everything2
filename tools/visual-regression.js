#!/usr/bin/env node

/**
 * Visual Regression Screenshot Tool
 *
 * Captures screenshots of all pages across all themes for visual regression testing.
 * Output: screenshots/{Theme Name}/{mobile,desktop}/{page}.png
 *
 * Usage:
 *   node tools/visual-regression.js                    # Full run (skips existing)
 *   node tools/visual-regression.js --force            # Regenerate all screenshots
 *   node tools/visual-regression.js --themes-only     # Just list themes
 *   node tools/visual-regression.js --pages-only      # Just list pages
 *   node tools/visual-regression.js --theme "jukka emulation"  # Single theme
 *   node tools/visual-regression.js --quick           # Quick subset for testing
 */

const puppeteer = require('puppeteer')
const fs = require('fs')
const path = require('path')

const BASE_URL = process.env.E2_BASE_URL || 'http://localhost:9080'
const SCREENSHOTS_DIR = path.join(__dirname, '..', 'screenshots')

// Viewport sizes
const VIEWPORTS = {
  desktop: { width: 1920, height: 1080 },
  mobile: { width: 375, height: 812 }  // iPhone X dimensions
}

// All themes from database (node_id => title mapping)
const THEMES = [
  { id: 1965286, name: 'Bare Understatement' },
  { id: 1973976, name: 'basesheet' },
  { id: 1928497, name: 'bookworm' },
  { id: 2000528, name: 'Bookwormier' },
  { id: 1926578, name: 'Cool understatement' },
  { id: 1996378, name: 'Deep Ice' },
  { id: 1997697, name: 'dim jukka emulation' },
  { id: 1997552, name: 'e2gle' },
  { id: 1905818, name: 'Gunpowder Green' },
  { id: 1855548, name: 'jukka emulation' },
  { id: 1926437, name: 'mikoyan25' },
  { id: 1951961, name: 'mikoyan25 flipped' },
  { id: 1983570, name: 'mikoyan25 light' },
  { id: 1965449, name: 'Monochrome understatement' },
  { id: 2029380, name: 'Pamphleteer' },
  { id: 2004473, name: 'print' },
  { id: 2041900, name: 'Simplicity' },
  { id: 1965235, name: 'Understatement' },
  { id: 1946242, name: 'Warm understatement' }
]

// All available nodelets for the "all nodelets" test page
// Map of nodelet name to node_id from database
const ALL_NODELET_IDS = [
  1935779,  // Categories
  170070,   // Chatterbox
  1689202,  // Current User Poll
  262,      // Epicenter
  836984,   // Everything Developer
  1876005,  // Favorite Noders
  2068913,  // For Review
  1687135,  // Master Control
  2044453,  // Messages
  1986723,  // Most Wanted
  2051342,  // Neglected Drafts
  1923735,  // New Logs
  263,      // New Writeups
  1290534,  // Notelet
  1930708,  // Notifications
  91,       // Other Users
  174581,   // Personal Links
  2146276,  // Quick Reference
  457857,   // Random Nodes
  1157024,  // ReadThis
  1322699,  // Recent Nodes
  2027508,  // Recommended Reading
  2029388,  // Sign in
  838296,   // Statistics
  1924754,  // Usergroup Writeups
  165437,   // Vitals
]

// Pages to screenshot - organized by category
const PAGES = {
  // Core content types
  content: [
    { name: 'e2node', url: '/title/tomato', desc: 'E2Node display' },
    { name: 'writeup', url: '/node/2212929', desc: 'Writeup display' },
    { name: 'user', url: '/user/root', desc: 'User homenode' },
    { name: 'usergroup', url: '/title/edev', desc: 'Usergroup display' },
    { name: 'category', url: '/title/Coffee+Culture', desc: 'Category display' },
    { name: 'registry', url: '/title/The+Registries', desc: 'Registry list' },
  ],

  // Special nodelet layout test - all nodelets enabled (desktop only - no nodelets on mobile)
  nodelet_test: [
    { name: 'all-nodelets', url: '/', desc: 'Home with all nodelets enabled', specialSetup: 'enableAllNodelets', desktopOnly: true },
  ],

  // Superdocs - public/user access
  superdocs: [
    { name: 'settings', url: '/title/Settings', desc: 'User settings' },
    { name: 'nodelet-settings', url: '/title/Nodelet+Settings', desc: 'Nodelet settings' },
    { name: 'search', url: '/title/Everything+User+Search', desc: 'User search' },
    { name: 'full-text-search', url: '/title/E2+Full+Text+Search', desc: 'Full text search' },
    { name: 'news', url: '/title/News+for+noders.+Stuff+that+matters.', desc: 'News page' },
    { name: 'most-wanted', url: '/title/Everything%27s+Most+Wanted', desc: 'Most wanted nodeshells' },
    { name: 'chatterlight', url: '/title/Chatterlight', desc: 'Chatterlight embed' },
    { name: 'achievements', url: '/title/My+Achievements', desc: 'User achievements' },
    { name: 'document-directory', url: '/title/Everything+Document+Directory', desc: 'Document directory' },
    { name: 'gift-shop', url: '/title/E2+Gift+Shop', desc: 'Gift shop' },
    { name: 'marble-shop', url: '/title/E2+Marble+Shop', desc: 'Marble shop' },
    { name: 'penny-jar', url: '/title/E2+Penny+Jar', desc: 'Penny jar' },
    { name: 'login', url: '/title/login', desc: 'Login page' },
    { name: 'signup', url: '/title/Sign+up', desc: 'Signup page' },
    { name: 'nothing-found', url: '/title/Nothing+Found', desc: 'Not found page' },
    { name: 'permission-denied', url: '/title/Permission+Denied', desc: 'Permission denied' },
    { name: 'alphabetizer', url: '/title/alphabetizer', desc: 'Alphabetizer tool' },
    { name: 'drafts', url: '/title/Drafts', desc: 'User drafts' },
    { name: 'drafts-for-review', url: '/title/Drafts+for+review', desc: 'Drafts for review' },
    { name: 'message-inbox', url: '/title/Message+Inbox', desc: 'Message inbox' },
    { name: 'my-writeups', url: '/title/My+Recent+Writeups', desc: 'Recent writeups' },
    { name: 'big-writeup-list', url: '/title/My+Big+Writeup+List', desc: 'Big writeup list' },
    { name: 'node-tracker', url: '/title/Node+Tracker', desc: 'Node tracker' },
    { name: 'nodeshells', url: '/title/Nodeshells', desc: 'Nodeshells list' },
    { name: 'your-nodeshells', url: '/title/Your+Nodeshells', desc: 'Your nodeshells' },
    { name: 'your-filled-nodeshells', url: '/title/Your+filled+nodeshells', desc: 'Filled nodeshells' },
    { name: 'available-rooms', url: '/title/Available+Rooms', desc: 'Chat rooms' },
    { name: 'poll-directory', url: '/title/Everything+Poll+Directory', desc: 'Poll directory' },
    { name: 'poll-creator', url: '/title/Everything+Poll+Creator', desc: 'Poll creator' },
    { name: 'poll-archive', url: '/title/Everything+Poll+Archive', desc: 'Poll archive' },
    { name: 'cool-archive', url: '/title/Cool+Archive', desc: 'Cool archive' },
    { name: 'page-of-cool', url: '/title/Page+of+Cool', desc: 'Page of cool' },
    { name: 'golden-trinkets', url: '/title/Golden+Trinkets', desc: 'Golden trinkets' },
    { name: 'silver-trinkets', url: '/title/Silver+Trinkets', desc: 'Silver trinkets' },
    { name: 'level-distribution', url: '/title/Level+Distribution', desc: 'Level distribution' },
    { name: 'reputation-graph', url: '/title/Reputation+Graph', desc: 'Reputation graph' },
    { name: 'iron-noder', url: '/title/iron+noder+progress', desc: 'Iron noder progress' },
    { name: 'year-ago-today', url: '/title/A+Year+Ago+Today', desc: 'A year ago today' },
    { name: 'between-cracks', url: '/title/Between+the+Cracks', desc: 'Between the cracks' },
    { name: 'bounty-hunters', url: '/title/Bounty+Hunters+Wanted', desc: 'Bounty hunters' },
    { name: 'bestow-easter-eggs', url: '/title/bestow+easter+eggs', desc: 'Bestow easter eggs (AdminBestowTool)' },
    { name: 'collaboration-nodes', url: '/title/E2+Collaboration+Nodes', desc: 'Collaboration nodes' },
    { name: 'quote-server', url: '/title/Everything+Quote+Server', desc: 'Quote server' },
    { name: 'i-ching', url: '/title/Everything+I+Ching', desc: 'I Ching' },
    { name: 'finger', url: '/title/Everything+Finger', desc: 'Everything finger' },
    { name: 'data-pages', url: '/title/Everything+Data+Pages', desc: 'Data pages' },
    { name: 'best-users', url: '/title/Everything%27s+Best+Users', desc: 'Best users' },
    { name: 'biggest-stars', url: '/title/Everything%27s+Biggest+Stars', desc: 'Biggest stars' },
    { name: 'obscure-writeups', url: '/title/Everything%27s+Obscure+Writeups', desc: 'Obscure writeups' },
    { name: 'voting-oracle', url: '/title/Voting+Oracle', desc: 'Voting oracle' },
    { name: 'voting-system', url: '/title/The+Everything2+Voting%2FExperience+System', desc: 'Voting system' },
    { name: 'recommender', url: '/title/The+Recommender', desc: 'The recommender' },
    { name: 'do-you-c', url: '/title/Do+You+C!+What+I+C%3F', desc: 'Do you C!' },
    { name: 'catwalk', url: '/title/The+Catwalk', desc: 'The catwalk' },
    { name: 'costume-shop', url: '/title/The+Costume+Shop', desc: 'Costume shop' },
    { name: 'theme-nirvana', url: '/title/Theme+Nirvana', desc: 'Theme nirvana' },
    { name: 'notelet-editor', url: '/title/Notelet+Editor', desc: 'Notelet editor' },
    { name: 'your-gravatar', url: '/title/Your+Gravatar', desc: 'Your gravatar' },
    { name: 'ignore-list', url: '/title/Your+ignore+list', desc: 'Ignore list' },
    { name: 'insured-writeups', url: '/title/Your+insured+writeups', desc: 'Insured writeups' },
    { name: 'site-trajectory', url: '/title/Site+Trajectory', desc: 'Site trajectory' },
    { name: 'noding-speedometer', url: '/title/Noding+speedometer', desc: 'Noding speedometer' },
    { name: 'nodes-of-year', url: '/title/Nodes+of+the+Year', desc: 'Nodes of the year' },
    { name: 'topic-archive', url: '/title/Topic+Archive', desc: 'Topic archive' },
    { name: 'log-archive', url: '/title/Log+Archive', desc: 'Log archive' },
    { name: 'acceptable-use', url: '/title/E2+Acceptable+Use+Policy', desc: 'Acceptable use' },
    { name: 'edev-faq', url: '/title/EDev+FAQ', desc: 'Edev FAQ' },
    { name: 'macro-faq', url: '/title/macro+FAQ', desc: 'Macro FAQ' },
    { name: 'editor-endorsements', url: '/title/Editor+Endorsements', desc: 'Editor endorsements' },
    { name: 'oblique-strategies', url: '/title/oblique+strategies+garden', desc: 'Oblique strategies' },
    { name: 'wheel-surprise', url: '/title/Wheel+of+Surprise', desc: 'Wheel of surprise' },
    { name: 'word-messer', url: '/title/word+messer-upper', desc: 'Word messer-upper' },
    { name: 'buffalo-generator', url: '/title/Buffalo+Generator', desc: 'Buffalo generator' },
    { name: 'text-formatter', url: '/title/Text+Formatter', desc: 'Text formatter' },
    { name: 'rot13', url: '/title/E2+Rot13+Encoder', desc: 'ROT13 encoder' },
    { name: 'source-formatter', url: '/title/E2+Source+Code+Formatter', desc: 'Source formatter' },
    { name: 'word-counter', url: '/title/E2+Word+Counter', desc: 'Word counter' },
    { name: 'sperm-counter', url: '/title/E2+Sperm+Counter', desc: 'Sperm counter' },
    { name: 'linebreaker', url: '/title/Wharfinger%27s+Linebreaker', desc: 'Linebreaker' },
    { name: 'color-toy', url: '/title/E2+Color+Toy', desc: 'Color toy' },
    { name: 'go-outside', url: '/title/Go+Outside', desc: 'Go outside' },
    { name: 'zenmastery', url: '/title/Zenmastery', desc: 'Zenmastery' },
    { name: 'christmas', url: '/title/Is+it+Christmas+yet%3F', desc: 'Is it Christmas?' },
    { name: 'halloween', url: '/title/Is+it+Halloween+yet%3F', desc: 'Is it Halloween?' },
  ],

  // Oppressor superdocs - editor+ access
  oppressor: [
    { name: 'content-reports', url: '/title/Content+Reports', desc: 'Content reports' },
    { name: 'fresh-blood', url: '/title/Fresh+Blood', desc: 'Fresh blood' },
    { name: 'freshly-bloodied', url: '/title/Freshly+Bloodied', desc: 'Freshly bloodied' },
    { name: 'best-writeups', url: '/title/Everything%27s+Best+Writeups', desc: 'Best writeups' },
    { name: 'publication-directory', url: '/title/Everything+Publication+Directory', desc: 'Publication directory' },
    { name: 'writeup-reparenter', url: '/title/Magical+Writeup+Reparenter', desc: 'Writeup reparenter' },
    { name: 'nodeshell-hopper', url: '/title/The+Nodeshell+Hopper', desc: 'Nodeshell hopper' },
    { name: 'what-does-what', url: '/title/What+Does+What', desc: 'What does what' },
    { name: 'who-doing-what', url: '/title/Who+is+Doing+What', desc: 'Who is doing what' },
    { name: 'recent-users', url: '/title/Recent+Users', desc: 'Recent users' },
    { name: 'server-telemetry', url: '/title/Server+Telemetry', desc: 'Server telemetry' },
    { name: 'websterbless', url: '/title/Websterbless', desc: 'Websterbless' },
    { name: 'mark-discussions-read', url: '/title/Mark+All+Discussions+as+Read', desc: 'Mark discussions read' },
  ],

  // Restricted superdocs - admin/god access
  restricted: [
    // AdminBestowTool pages - unified component for granting resources
    { name: 'bestow-cools', url: '/title/bestow+cools', desc: 'Bestow cools (AdminBestowTool)' },
    { name: 'superbless', url: '/title/Superbless', desc: 'Superbless GP (AdminBestowTool)' },
    { name: 'xp-superbless', url: '/title/XP+Superbless', desc: 'XP Superbless (AdminBestowTool)' },
    { name: 'enrichify', url: '/title/Enrichify', desc: 'Enrichify GP (AdminBestowTool)' },
    { name: 'giant-teddy-bear-suit', url: '/title/Giant+Teddy+Bear+Suit', desc: 'Giant Teddy Bear Suit (AdminBestowTool)' },
    { name: 'fiery-teddy-bear-suit', url: '/title/Fiery+Teddy+Bear+Suit', desc: 'Fiery Teddy Bear Suit (AdminBestowTool)' },
    { name: 'well-of-cool', url: '/title/The+Well+of+Cool', desc: 'Well of Cool (AdminBestowTool)' },
    // Other restricted superdocs
    { name: 'cache-dump', url: '/title/Cache+Dump', desc: 'Cache dump' },
    { name: 'create-node', url: '/title/Create+Node', desc: 'Create node' },
    { name: 'e2node-reparenter', url: '/title/E2Node+Reparenter', desc: 'E2Node reparenter' },
    { name: 'richest-noders', url: '/title/Everything%27s+Richest+Noders', desc: 'Richest noders' },
    { name: 'statistics', url: '/title/Everything+Statistics', desc: 'Everything statistics' },
    { name: 'faq-editor', url: '/title/FAQ+Editor', desc: 'FAQ editor' },
    { name: 'feed-edb', url: '/title/Feed+eDB', desc: 'Feed eDB' },
    { name: 'gp-optouts', url: '/title/GP+Optouts', desc: 'GP optouts' },
    { name: 'ip2name', url: '/title/ip2name', desc: 'IP to name' },
    { name: 'ip-blacklist', url: '/title/IP+Blacklist', desc: 'IP blacklist' },
    { name: 'ip-hunter', url: '/title/IP+Hunter', desc: 'IP hunter' },
    { name: 'klaproth-van-lines', url: '/title/Klaproth+Van+Lines', desc: 'Klaproth van lines' },
    { name: 'mass-ip-blacklist', url: '/title/Mass+IP+Blacklister', desc: 'Mass IP blacklister' },
    { name: 'unborg-doc', url: '/title/Nate%27s+Secret+Unborg+Doc', desc: 'Unborg doc' },
    { name: 'node-forbiddance', url: '/title/Node+Forbiddance', desc: 'Node forbiddance' },
    { name: 'node-heaven-search', url: '/title/Node+Heaven+Title+Search', desc: 'Node heaven search' },
    { name: 'node-notes-editor', url: '/title/Node+Notes+by+Editor', desc: 'Node notes by editor' },
    { name: 'nodetype-changer', url: '/title/Nodetype+Changer', desc: 'Nodetype changer' },
    { name: 'sql-prompt', url: '/title/SQL+Prompt', desc: 'SQL prompt' },
    { name: 'borg-clinic', url: '/title/The+Borg+Clinic', desc: 'Borg clinic' },
    { name: 'node-crypt', url: '/title/The+Node+Crypt', desc: 'Node crypt' },
    { name: 'old-hooked-pole', url: '/title/The+Old+Hooked+Pole', desc: 'Old hooked pole' },
    { name: 'oracle', url: '/title/The+Oracle', desc: 'The Oracle' },
    { name: 'tokenator', url: '/title/The+Tokenator', desc: 'The tokenator' },
    { name: 'user-statistics', url: '/title/User+Statistics', desc: 'User statistics' },
    { name: 'usergroup-attendance', url: '/title/Usergroup+Attendance+Monitor', desc: 'Usergroup attendance' },
    { name: 'usergroup-archive-manager', url: '/title/Usergroup+Message+Archive+Manager', desc: 'Archive manager' },
    { name: 'infravision', url: '/title/Users+with+Infravision', desc: 'Users with infravision' },
    { name: 'voting-data', url: '/title/Voting+Data', desc: 'Voting data' },
    { name: 'who-killed-what', url: '/title/Who+Killed+What', desc: 'Who killed what' },
  ],

  // Edit pages for various nodetypes
  edit: [
    { name: 'edit-writeup', url: '/title/tomato?displaytype=edit', desc: 'Edit writeup' },
    { name: 'edit-user', url: '/user/e2e_admin?displaytype=edit', desc: 'Edit user homenode' },
    { name: 'edit-draft', url: '/title/Drafts', desc: 'Draft editing (via drafts page)' },
  ],

  // Fullpage interfaces
  fullpage: [
    { name: 'chatterlight-full', url: '/title/chatterlight', desc: 'Chatterlight fullpage' },
  ],
}

// Quick subset for testing
const QUICK_PAGES = [
  { name: 'home', url: '/', desc: 'Home page' },
  { name: 'e2node', url: '/title/tomato', desc: 'E2Node' },
  { name: 'settings', url: '/title/Settings', desc: 'Settings' },
  { name: 'search', url: '/title/Everything+User+Search', desc: 'Search' },
]

// Sanitize filename
function sanitizeFilename(name) {
  return name.replace(/[^a-zA-Z0-9-_]/g, '_').toLowerCase()
}

// Create directory if not exists (with recursive: true to create parent directories)
function ensureDir(dir) {
  fs.mkdirSync(dir, { recursive: true })
}

// Check if screenshot already exists
function screenshotExists(themeName, viewportName, pageName) {
  const themeDir = path.join(SCREENSHOTS_DIR, sanitizeFilename(themeName), viewportName)
  const filename = `${sanitizeFilename(pageName)}.png`
  const filepath = path.join(themeDir, filename)
  return fs.existsSync(filepath)
}

// Login and set theme
async function loginAndSetTheme(page, themeId) {
  // Login via API (the form uses React and submits via API)
  await page.goto(`${BASE_URL}/`, { waitUntil: 'networkidle2', timeout: 60000 })

  const loginResult = await page.evaluate(async () => {
    const response = await fetch('/api/sessions/create', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'same-origin',
      body: JSON.stringify({ username: 'e2e_admin', passwd: 'test123', expires: '+1y' })
    })
    return response.ok
  })

  if (!loginResult) {
    throw new Error('Login failed')
  }

  // Reload to apply session
  await page.goto(`${BASE_URL}/`, { waitUntil: 'networkidle2', timeout: 60000 })

  // Set theme via API - userstyle takes the node_id as a string
  const setThemeResult = await page.evaluate(async (themeId) => {
    const response = await fetch('/api/preferences/set', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ userstyle: String(themeId) })
    })
    return response.ok
  }, themeId)

  if (!setThemeResult) {
    throw new Error('Failed to set theme')
  }

  // Navigate away and back to apply theme
  await page.goto(`${BASE_URL}/`, { waitUntil: 'networkidle2', timeout: 60000 })
}

// Enable all nodelets for the special nodelet test page
async function enableAllNodelets(page) {
  // Enable all nodelets via POST /api/nodelets with nodelet_ids array
  const result = await page.evaluate(async (nodeletIds) => {
    const response = await fetch('/api/nodelets', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ nodelet_ids: nodeletIds })
    })
    return response.ok
  }, ALL_NODELET_IDS)

  if (!result) {
    console.log('  Warning: Failed to enable all nodelets')
  }

  // Reload to apply changes
  await page.goto(`${BASE_URL}/`, { waitUntil: 'networkidle2', timeout: 60000 })
}

// Take screenshot of a page
async function takeScreenshot(page, pageInfo, themeName, viewport, force = false) {
  const viewportName = viewport === VIEWPORTS.desktop ? 'desktop' : 'mobile'
  const themeDir = path.join(SCREENSHOTS_DIR, sanitizeFilename(themeName), viewportName)
  ensureDir(themeDir)

  const filename = `${sanitizeFilename(pageInfo.name)}.png`
  const filepath = path.join(themeDir, filename)

  // Skip if already exists and not forcing
  if (!force && fs.existsSync(filepath)) {
    return { success: true, path: filepath, skipped: true }
  }

  try {
    // Handle special setup if needed
    if (pageInfo.specialSetup === 'enableAllNodelets') {
      await enableAllNodelets(page)
    }

    // Reset to base viewport first to avoid issues with large viewports
    await page.setViewport({ width: viewport.width, height: viewport.height })

    await page.goto(`${BASE_URL}${pageInfo.url}`, { waitUntil: 'networkidle2', timeout: 60000 })

    // Wait for React to hydrate
    await page.waitForSelector('#pagecontent, .e2-page, [data-reactroot]', { timeout: 5000 }).catch(() => {})

    // Wait a bit for any animations/loading
    await page.evaluate(() => new Promise(r => setTimeout(r, 500)))

    // For desktop, capture full page height
    if (viewport === VIEWPORTS.desktop) {
      // Get the full page height
      const bodyHandle = await page.$('body')
      const boundingBox = await bodyHandle.boundingBox()
      await bodyHandle.dispose()

      if (boundingBox) {
        // Set viewport to full page height (capped at 15000px for nodelet tests, 10000px otherwise)
        const maxHeight = pageInfo.specialSetup === 'enableAllNodelets' ? 15000 : 10000
        const fullHeight = Math.min(Math.ceil(boundingBox.height), maxHeight)
        await page.setViewport({ width: viewport.width, height: fullHeight })
      }
    }

    await page.screenshot({
      path: filepath,
      fullPage: viewport === VIEWPORTS.desktop
    })

    return { success: true, path: filepath, skipped: false }
  } catch (err) {
    return { success: false, error: err.message, path: filepath, skipped: false }
  }
}

async function main() {
  const args = process.argv.slice(2)

  // Handle flags
  if (args.includes('--themes-only')) {
    console.log('Available themes:')
    THEMES.forEach(t => console.log(`  - ${t.name} (id: ${t.id})`))
    return
  }

  if (args.includes('--pages-only')) {
    console.log('Pages to screenshot:')
    for (const [category, pages] of Object.entries(PAGES)) {
      console.log(`\n${category}:`)
      pages.forEach(p => console.log(`  - ${p.name}: ${p.desc}`))
    }
    return
  }

  const quickMode = args.includes('--quick')
  const forceMode = args.includes('--force')
  const singleThemeIdx = args.indexOf('--theme')
  const singleTheme = singleThemeIdx !== -1 ? args[singleThemeIdx + 1] : null

  // Get themes to process
  let themesToProcess = THEMES
  if (singleTheme) {
    themesToProcess = THEMES.filter(t =>
      t.name.toLowerCase().includes(singleTheme.toLowerCase())
    )
    if (themesToProcess.length === 0) {
      console.error(`No theme matching "${singleTheme}" found`)
      process.exit(1)
    }
  }

  // Get pages to process
  let pagesToProcess = quickMode
    ? QUICK_PAGES
    : Object.values(PAGES).flat()

  console.log('Visual Regression Screenshot Tool')
  console.log('==================================\n')
  console.log(`Themes: ${themesToProcess.length}`)
  console.log(`Pages: ${pagesToProcess.length}`)
  console.log(`Viewports: desktop, mobile`)
  console.log(`Total possible: ${themesToProcess.length * pagesToProcess.length * 2}`)
  console.log(`Mode: ${forceMode ? 'Force regenerate all' : 'Skip existing screenshots'}\n`)

  // Ensure screenshots directory exists
  ensureDir(SCREENSHOTS_DIR)

  // Browser recycling - restart browser every N themes to prevent memory issues
  const THEMES_PER_BROWSER = 5
  let browser = null
  let page = null
  let themesProcessed = 0

  async function closeBrowserSafely() {
    if (browser) {
      try {
        // Use a timeout to prevent hanging on browser.close()
        await Promise.race([
          browser.close(),
          new Promise((_, reject) => setTimeout(() => reject(new Error('Browser close timeout')), 10000))
        ])
      } catch (err) {
        console.log(`  Warning: Browser close issue: ${err.message}`)
        // Force kill any remaining processes
        try {
          const browserProcess = browser.process()
          if (browserProcess) {
            browserProcess.kill('SIGKILL')
          }
        } catch (killErr) {
          // Ignore kill errors
        }
      }
      browser = null
      page = null
    }
  }

  async function ensureBrowser() {
    if (!browser || themesProcessed >= THEMES_PER_BROWSER) {
      if (browser) {
        console.log('  Recycling browser to free memory...')
        await closeBrowserSafely()
      }
      browser = await puppeteer.launch({
        headless: 'new',
        args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage'],
        protocolTimeout: 60000  // 60 second protocol timeout
      })
      page = await browser.newPage()
      // Set default timeout for all operations
      page.setDefaultTimeout(60000)
      themesProcessed = 0
    }
    return page
  }

  const results = {
    success: 0,
    skipped: 0,
    failed: 0,
    errors: []
  }

  for (const theme of themesToProcess) {
    console.log(`\nTheme: ${theme.name}`)
    console.log('-'.repeat(40))

    // Check if we need to process any pages for this theme
    const needsProcessing = forceMode || pagesToProcess.some(pageInfo => {
      return Object.keys(VIEWPORTS).some(viewportName => {
        return !screenshotExists(theme.name, viewportName, pageInfo.name)
      })
    })

    if (!needsProcessing) {
      console.log('  All screenshots exist, skipping theme')
      results.skipped += pagesToProcess.length * Object.keys(VIEWPORTS).length
      continue
    }

    // Ensure browser is running and get page
    try {
      page = await ensureBrowser()
    } catch (err) {
      console.error(`  Failed to launch browser: ${err.message}`)
      continue
    }

    // Login and set theme
    try {
      await loginAndSetTheme(page, theme.id)
      console.log('  Logged in and theme set')
      themesProcessed++
    } catch (err) {
      console.error(`  Failed to set theme: ${err.message}`)
      // Force browser restart on next iteration
      themesProcessed = THEMES_PER_BROWSER
      continue
    }

    for (const pageInfo of pagesToProcess) {
      for (const [viewportName, viewport] of Object.entries(VIEWPORTS)) {
        // Skip mobile for desktop-only pages (e.g., all-nodelets - no nodelets on mobile)
        if (pageInfo.desktopOnly && viewportName === 'mobile') {
          continue
        }

        // Check if screenshot exists (unless forcing)
        if (!forceMode && screenshotExists(theme.name, viewportName, pageInfo.name)) {
          results.skipped++
          continue
        }

        process.stdout.write(`  ${pageInfo.name} (${viewportName})... `)

        const result = await takeScreenshot(page, pageInfo, theme.name, viewport, forceMode)

        if (result.skipped) {
          console.log('SKIPPED')
          results.skipped++
        } else if (result.success) {
          console.log('OK')
          results.success++
        } else {
          console.log(`FAILED: ${result.error}`)
          results.failed++
          results.errors.push({
            theme: theme.name,
            page: pageInfo.name,
            viewport: viewportName,
            error: result.error
          })
        }
      }
    }
  }

  await closeBrowserSafely()

  // Summary
  console.log('\n\nSummary')
  console.log('=======')
  console.log(`Generated: ${results.success}`)
  console.log(`Skipped (existing): ${results.skipped}`)
  console.log(`Failed: ${results.failed}`)

  if (results.errors.length > 0) {
    console.log('\nErrors:')
    results.errors.forEach(e => {
      console.log(`  - ${e.theme}/${e.viewport}/${e.page}: ${e.error}`)
    })
  }

  console.log(`\nScreenshots saved to: ${SCREENSHOTS_DIR}`)
}

main().catch(err => {
  console.error('Fatal error:', err)
  process.exit(1)
})
