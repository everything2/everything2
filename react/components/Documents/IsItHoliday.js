import React from 'react'

/**
 * Is It Holiday - Fun holiday date checker pages
 *
 * Phase 4a migration from Mason template is_it_holiday.mc
 * Shows: Giant YES/NO based on current date matching the occasion
 *
 * Used by 5 pages:
 * - is it christmas yet (xmas)
 * - is it halloween yet (halloween)
 * - is it new year's day yet (nyd)
 * - is it new year's eve yet (nye)
 * - is it april fools day yet (afd)
 */
const IsItHoliday = ({ data }) => {
  const { occasion } = data

  /**
   * Check if today matches the special date
   * Logic ported from templates/helpers/is_special_date.mi
   */
  const isSpecialDate = (occ) => {
    const now = new Date()
    const month = now.getUTCMonth() // 0-11 (January is 0)
    const day = now.getUTCDate()    // 1-31

    const occasionLower = occ.toLowerCase()

    // Check each occasion
    if (occasionLower.startsWith('afd')) {
      // April Fools Day: April 1 (month 3, day 1)
      return month === 3 && day === 1
    } else if (occasionLower.startsWith('halloween')) {
      // Halloween: October 31 (month 9, day 31)
      return month === 9 && day === 31
    } else if (occasionLower.startsWith('xmas')) {
      // Christmas: December 25 (month 11, day 25)
      return month === 11 && day === 25
    } else if (occasionLower.startsWith('nye')) {
      // New Year's Eve: December 31 (month 11, day 31)
      return month === 11 && day === 31
    } else if (occasionLower.startsWith('nyd')) {
      // New Year's Day: January 1 (month 0, day 1)
      return month === 0 && day === 1
    }

    return false
  }

  const isToday = isSpecialDate(occasion)

  return (
    <div
      className="is-it-holiday"
      style={{ textAlign: 'center', padding: '40px 20px' }}
    >
      <br />
      <br />
      <p style={{ fontSize: '64px', fontWeight: 'bold', margin: 0 }}>
        {isToday ? 'YES' : 'NO'}
      </p>
    </div>
  )
}

export default IsItHoliday
