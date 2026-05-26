import {
  formatDate,
  formatShortDate,
  formatDateTime,
  formatTime,
  formatMessageTimestamp,
  isValidDate,
  __toDate,
} from './dateFormat'

describe('dateFormat utility', () => {
  describe('formatDate (long form, UTC)', () => {
    it('renders ISO-Z timestamps in UTC, not viewer local TZ', () => {
      // The motivating case from issue #4056 — Oolong's join time
      expect(formatDate('2001-04-14T23:28:51Z')).toBe('April 14, 2001')
    })

    it('treats MySQL-style "YYYY-MM-DD HH:MM:SS" strings as UTC', () => {
      expect(formatDate('2001-04-14 23:28:51')).toBe('April 14, 2001')
    })

    it('accepts epoch seconds (number)', () => {
      // 2001-04-14T23:28:51Z = 987 290 931 seconds
      expect(formatDate(987290931)).toBe('April 14, 2001')
    })

    it('accepts epoch milliseconds (heuristic when > 1e12)', () => {
      expect(formatDate(987290931000)).toBe('April 14, 2001')
    })

    it('accepts Date objects', () => {
      expect(formatDate(new Date('2001-04-14T23:28:51Z'))).toBe('April 14, 2001')
    })

    it('returns null for null, undefined, and empty string', () => {
      expect(formatDate(null)).toBeNull()
      expect(formatDate(undefined)).toBeNull()
      expect(formatDate('')).toBeNull()
    })

    it('returns null for invalid date strings', () => {
      expect(formatDate('not a date')).toBeNull()
    })

    it('returns null for epoch 0 (E2 "never" sentinel)', () => {
      expect(formatDate('1970-01-01T00:00:00Z')).toBeNull()
      expect(formatDate(0)).toBeNull()
    })

    it('allows TZ override for callers that genuinely want local time', () => {
      expect(formatDate('2001-04-14T23:28:51Z', { timeZone: 'Europe/London' })).toBe('April 15, 2001')
    })
  })

  describe('formatShortDate', () => {
    it('uses short month names', () => {
      expect(formatShortDate('2001-04-14T23:28:51Z')).toBe('Apr 14, 2001')
    })
  })

  describe('formatDateTime', () => {
    it('includes time component in UTC', () => {
      const out = formatDateTime('2001-04-14T23:28:51Z')
      expect(out).toMatch(/Apr 14, 2001/)
      expect(out).toMatch(/11:28/)
    })
  })

  describe('formatTime', () => {
    it('renders time-of-day in UTC', () => {
      const out = formatTime('2001-04-14T23:28:51Z')
      expect(out).toMatch(/11:28/)
    })
  })

  describe('isValidDate', () => {
    it('returns true for valid dates', () => {
      expect(isValidDate('2001-04-14T23:28:51Z')).toBe(true)
      expect(isValidDate(new Date())).toBe(true)
      expect(isValidDate(1000000)).toBe(true)
    })

    it('returns false for invalid / null / epoch-0', () => {
      expect(isValidDate(null)).toBe(false)
      expect(isValidDate(undefined)).toBe(false)
      expect(isValidDate('')).toBe(false)
      expect(isValidDate('not a date')).toBe(false)
      expect(isValidDate(0)).toBe(false)
      expect(isValidDate('1970-01-01T00:00:00Z')).toBe(false)
    })
  })

  describe('__toDate (internal)', () => {
    it('rejects Date instances with NaN time', () => {
      expect(__toDate(new Date('garbage'))).toBeNull()
    })
  })

  describe('formatMessageTimestamp (3-tier message UI)', () => {
    // Pin "now" so the today / this-year / older branches are deterministic.
    // 2026-05-26 in local time matches the dev TZ at test time and keeps the
    // tier boundaries crisp regardless of where the test runs.
    let realDate
    beforeEach(() => {
      realDate = global.Date
      const FAKE_NOW = new realDate(2026, 4, 26, 12, 0, 0) // May 26, 2026 local
      global.Date = class extends realDate {
        constructor(...args) {
          if (args.length === 0) return new realDate(FAKE_NOW)
          return new realDate(...args)
        }
        static now() { return FAKE_NOW.getTime() }
      }
      global.Date.UTC = realDate.UTC
      global.Date.parse = realDate.parse
    })
    afterEach(() => {
      global.Date = realDate
    })

    it('today → time only (24h)', () => {
      // Use a local-time message earlier today
      const today = '2026-05-26T14:34:00'  // no Z → parsed as local
      expect(formatMessageTimestamp(today)).toBe('14:34')
    })

    it('this year, not today → month + day + time, no year', () => {
      const mar = '2026-03-05T14:34:00'
      const out = formatMessageTimestamp(mar)
      expect(out).toContain('Mar 5')
      expect(out).toContain('14:34')
      expect(out).not.toContain('2026')
    })

    it('previous year → year is shown alongside month + day + time (#4123)', () => {
      const old = '2024-03-05T14:34:00'
      const out = formatMessageTimestamp(old)
      expect(out).toContain('Mar 5')
      expect(out).toContain('2024')
      expect(out).toContain('14:34')
    })

    it('compact mode drops the time on non-today entries', () => {
      const thisYear = '2026-03-05T14:34:00'
      const lastYear = '2024-03-05T14:34:00'
      expect(formatMessageTimestamp(thisYear, { compact: true })).not.toContain('14:34')
      expect(formatMessageTimestamp(thisYear, { compact: true })).toContain('Mar 5')
      expect(formatMessageTimestamp(lastYear, { compact: true })).toContain('2024')
    })

    it('compact mode still shows time-only for today (the at-a-glance signal)', () => {
      const today = '2026-05-26T14:34:00'
      expect(formatMessageTimestamp(today, { compact: true })).toBe('14:34')
    })

    it('hour12 option uses 12-hour format with single-digit hour (mobile convention)', () => {
      const today = '2026-05-26T14:34:00'
      const out = formatMessageTimestamp(today, { hour12: true })
      // Locale-dependent, but should contain a PM marker and "2:34" not "02:34"
      expect(out).toMatch(/2:34/)
      expect(out).toMatch(/PM/i)
    })

    it('returns null for null / invalid / epoch-0 input', () => {
      expect(formatMessageTimestamp(null)).toBeNull()
      expect(formatMessageTimestamp(undefined)).toBeNull()
      expect(formatMessageTimestamp('')).toBeNull()
      expect(formatMessageTimestamp('not a date')).toBeNull()
      expect(formatMessageTimestamp(0)).toBeNull()
    })
  })
})
