import React from 'react'
import TimeDistance from './TimeDistance'

/**
 * TimeSince - Display time elapsed since a timestamp
 *
 * Accepts:
 * - Unix timestamp (number, seconds since epoch)
 * - MySQL datetime string ("2025-12-10 19:33:59")
 * - ISO 8601 datetime string ("2025-12-10T19:33:59Z")
 *
 * Converts to Unix timestamp for TimeDistance component.
 */
const TimeSince = ({ timestamp }) => {
  let unixTime = timestamp

  // If it's a string, convert to Unix timestamp
  if (typeof timestamp === 'string') {
    // Check if it's already ISO format (contains T)
    if (timestamp.includes('T')) {
      // ISO 8601 format: "2025-12-10T19:33:59Z"
      unixTime = Math.floor(new Date(timestamp).getTime() / 1000)
    } else {
      // MySQL datetime format: "2025-12-10 19:33:59"
      // Convert to ISO format for Date parsing, assume UTC
      const isoString = timestamp.replace(' ', 'T') + 'Z'
      unixTime = Math.floor(new Date(isoString).getTime() / 1000)
    }
  }

  return <TimeDistance then={unixTime} />
}

export default TimeSince
