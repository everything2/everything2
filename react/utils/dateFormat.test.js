import {
  formatDate,
  formatShortDate,
  formatDateTime,
  formatTime,
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
})
