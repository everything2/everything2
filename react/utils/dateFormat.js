/**
 * Shared date formatting for E2 React components.
 *
 * E2's server stores all timestamps in UTC (Apache runs `$ENV{TZ} = '+0000'`).
 * Writeup createtime/publishtime, user createtime/lasttime, message timestamps,
 * etc., all come down as ISO-8601 strings ending in `Z` (e.g. `2001-04-14T23:28:51Z`).
 *
 * The trap: `Date.prototype.toLocaleDateString` defaults to the *viewer's*
 * local timezone. For a UTC timestamp late in the day, viewers east of UTC see
 * the date rolled forward one day. Issue #4056 was exactly this — Oolong's
 * `2001-04-14T23:28:51Z` join rendered as April 15 for UK (BST = UTC+1) viewers.
 *
 * All formatters here default to `timeZone: 'UTC'` so the *calendar date*
 * shown matches the *calendar date* stored in the database, and matches the
 * date shown in the legacy E2 system and on writeup pages. Callers needing
 * local-TZ behavior can override `timeZone` explicitly.
 *
 * Inputs accepted:
 *   - ISO-8601 string: `'2001-04-14T23:28:51Z'`
 *   - MySQL-style string: `'2001-04-14 23:28:51'` (treated as UTC)
 *   - Epoch seconds (number, since E2 some legacy data is stored this way)
 *   - Date object
 *
 * Returns `null` for null/undefined/invalid/epoch-0 input. Callers handle
 * fallback display (e.g. `formatDate(x) ?? <em>forever</em>`).
 */

const toDate = (input) => {
  if (input == null || input === '') return null

  if (input instanceof Date) {
    return isNaN(input.getTime()) ? null : input
  }

  if (typeof input === 'number') {
    // Epoch seconds (the legacy convention). Detect epoch milliseconds by
    // sniffing the magnitude — anything past year 2200 in seconds is far
    // more likely to be ms.
    if (input <= 0) return null  // epoch 0 / negative = E2's "never" sentinel
    // Heuristic: anything past ~year 2286 (1e10 seconds) is almost certainly ms,
    // anything below is almost certainly seconds. Real E2 data is all 1990s+.
    const ms = input > 1e10 ? input : input * 1000
    const d = new Date(ms)
    return isNaN(d.getTime()) ? null : d
  }

  if (typeof input === 'string') {
    // MySQL-style "YYYY-MM-DD HH:MM:SS" lacks a TZ marker; JS would parse it
    // as local time. Force UTC interpretation by inserting the T and Z.
    let parsable = input
    const mysqlShape = /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/
    if (mysqlShape.test(input)) {
      parsable = input.replace(' ', 'T') + 'Z'
    }
    const d = new Date(parsable)
    if (isNaN(d.getTime())) return null
    // Reject epoch 0 / negative epochs — these are placeholder "never" values
    // in E2's database (e.g. `lasttime` for users who never logged in).
    if (d.getTime() <= 0) return null
    return d
  }

  return null
}

const DEFAULT_DATE_OPTIONS = {
  year: 'numeric',
  month: 'long',
  day: 'numeric',
  timeZone: 'UTC',
}

const DEFAULT_SHORT_DATE_OPTIONS = {
  year: 'numeric',
  month: 'short',
  day: 'numeric',
  timeZone: 'UTC',
}

const DEFAULT_DATETIME_OPTIONS = {
  year: 'numeric',
  month: 'short',
  day: 'numeric',
  hour: '2-digit',
  minute: '2-digit',
  timeZone: 'UTC',
}

const DEFAULT_TIME_OPTIONS = {
  hour: '2-digit',
  minute: '2-digit',
  timeZone: 'UTC',
}

const DEFAULT_LOCALE = 'en-US'

/**
 * Long-form calendar date, e.g. "April 14, 2001". UTC.
 */
export function formatDate(input, options = {}) {
  const date = toDate(input)
  if (!date) return null
  return date.toLocaleDateString(DEFAULT_LOCALE, { ...DEFAULT_DATE_OPTIONS, ...options })
}

/**
 * Short calendar date, e.g. "Apr 14, 2001". UTC.
 */
export function formatShortDate(input, options = {}) {
  const date = toDate(input)
  if (!date) return null
  return date.toLocaleDateString(DEFAULT_LOCALE, { ...DEFAULT_SHORT_DATE_OPTIONS, ...options })
}

/**
 * Date + time, e.g. "Apr 14, 2001, 11:28 PM". UTC.
 */
export function formatDateTime(input, options = {}) {
  const date = toDate(input)
  if (!date) return null
  return date.toLocaleString(DEFAULT_LOCALE, { ...DEFAULT_DATETIME_OPTIONS, ...options })
}

/**
 * Just time, e.g. "11:28 PM". UTC.
 */
export function formatTime(input, options = {}) {
  const date = toDate(input)
  if (!date) return null
  return date.toLocaleTimeString(DEFAULT_LOCALE, { ...DEFAULT_TIME_OPTIONS, ...options })
}

/**
 * Smart timestamp for message UIs (private message lists, sent tab, mobile
 * drawers). Returns just enough date context for the message's age so that
 * returning users can tell a message from this morning apart from one from
 * 2019 without every entry shouting a full year.
 *
 *   Same day            → "14:34"
 *   This year           → "Mar 5, 14:34"          (compact: "Mar 5")
 *   Previous year+      → "Mar 5, 2024, 14:34"    (compact: "Mar 5, 2024")
 *
 * Unlike formatDate/formatShortDate/etc., this renders in the *viewer's local
 * timezone*. For messages, "when did this arrive for me" is the right answer;
 * UTC is the right answer for calendar-date metadata on writeups and profiles.
 * The same-day comparison uses local TZ too so a 23:50 UTC message doesn't
 * render as "Apr 15" while being classified as "today" by UTC math.
 *
 * 24-hour time everywhere to match the existing inline message-UI conventions.
 *
 * @param {*} input timestamp (any shape accepted by toDate)
 * @param {Object} [options]
 * @param {boolean} [options.compact=false] omit the time portion on older
 *   messages (chat-style lists where time is the primary at-a-glance signal).
 * @param {boolean} [options.hour12=false] use 12-hour format ("2:34 PM").
 *   Default is 24-hour to match the desktop message UI convention; mobile
 *   passes true.
 * @returns {string|null} formatted string, or null for invalid input
 */
export function formatMessageTimestamp(input, options = {}) {
  const date = toDate(input)
  if (!date) return null

  const compact = options.compact === true
  const hour12 = options.hour12 === true
  // 12h conventionally uses single-digit hour ("2:34 PM"); 24h uses two-digit
  // ("02:34"). Matches the convention in the legacy bespoke formatters.
  const hour = hour12 ? 'numeric' : '2-digit'
  const timeOpts = { hour, minute: '2-digit', hour12 }

  const now = new Date()

  const sameLocalDay = (
    date.getFullYear() === now.getFullYear() &&
    date.getMonth() === now.getMonth() &&
    date.getDate() === now.getDate()
  )

  if (sameLocalDay) {
    return date.toLocaleTimeString(DEFAULT_LOCALE, timeOpts)
  }

  const sameYear = date.getFullYear() === now.getFullYear()

  if (compact) {
    return date.toLocaleDateString(DEFAULT_LOCALE, sameYear
      ? { month: 'short', day: 'numeric' }
      : { year: 'numeric', month: 'short', day: 'numeric' }
    )
  }

  return date.toLocaleString(DEFAULT_LOCALE, sameYear
    ? { month: 'short', day: 'numeric', ...timeOpts }
    : { year: 'numeric', month: 'short', day: 'numeric', ...timeOpts }
  )
}

/**
 * Whether the input parses to a valid, non-epoch-zero date.
 * Useful for conditionally rendering "(<TimeSince>)" alongside `formatDate`.
 */
export function isValidDate(input) {
  return toDate(input) !== null
}

// Internal helper exported for tests
export const __toDate = toDate
