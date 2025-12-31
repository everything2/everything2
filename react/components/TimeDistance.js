import React from 'react'

/**
 * TimeDistance - Display time elapsed since/until a Unix timestamp
 *
 * Shows the highest significant time unit in a human-readable format.
 * e.g., "5 minutes ago", "3 hours ago", "2 days ago", "1 week ago"
 *
 * @param {number} then - Unix timestamp (seconds since epoch)
 * @param {number} now - Optional current timestamp for testing
 */
const TimeDistance = ({then, now}) => {
  if (now === undefined) {
    now = Math.floor(Date.now() / 1000)
  }

  let suffix = 'ago'
  if (then > now) {
    suffix = 'in the future'
    const tmp = then
    then = now
    now = tmp
  }

  if (then === 0) {
    return 'forever ago'
  }

  const timeDiff = now - then
  const minutes = Math.floor(timeDiff / 60)
  const hours = Math.floor(timeDiff / (60 * 60))
  const days = Math.floor(timeDiff / (60 * 60 * 24))
  const weeks = Math.floor(days / 7)
  const months = Math.floor(days / 30)
  const years = Math.floor(days / 365)

  let timeStr

  if (timeDiff < 60) {
    timeStr = timeDiff === 1 ? '1 second' : `${timeDiff} seconds`
  } else if (minutes < 60) {
    timeStr = minutes === 1 ? '1 minute' : `${minutes} minutes`
  } else if (hours < 24) {
    timeStr = hours === 1 ? '1 hour' : `${hours} hours`
  } else if (days < 7) {
    timeStr = days === 1 ? '1 day' : `${days} days`
  } else if (weeks < 4) {
    timeStr = weeks === 1 ? '1 week' : `${weeks} weeks`
  } else if (months < 12) {
    timeStr = months === 1 ? '1 month' : `${months} months`
  } else {
    timeStr = years === 1 ? '1 year' : `${years} years`
  }

  return <>{timeStr} {suffix}</>
}

export default TimeDistance
