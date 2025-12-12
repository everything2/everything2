import React from 'react'
import TimeDistance from './TimeDistance'

/**
 * TimeSince - Display time elapsed since a timestamp
 *
 * Accepts either:
 * - Unix timestamp (number, seconds since epoch)
 * - MySQL datetime string ("2025-12-10 19:33:59")
 *
 * Converts to Unix timestamp for TimeDistance component.
 */
const TimeSince = ({ timestamp }) => {
  let unixTime = timestamp

  // If it's a string (MySQL datetime), convert to Unix timestamp
  if (typeof timestamp === 'string') {
    // MySQL datetime format: "2025-12-10 19:33:59"
    // Convert to ISO format for Date parsing, assume UTC
    const isoString = timestamp.replace(' ', 'T') + 'Z'
    unixTime = Math.floor(new Date(isoString).getTime() / 1000)
  }

  return <TimeDistance then={unixTime} />
}

export default TimeSince
