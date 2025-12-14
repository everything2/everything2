import React from 'react'
import WriteupDisplay from '../WriteupDisplay'

/**
 * Writeup Document Component
 *
 * Renders a single writeup page using React-based E2 link parsing.
 * Replaces server-side Mason2 templates with client-side React.
 *
 * Data comes from Everything::Page::writeup->buildReactData()
 */
const Writeup = ({ data }) => {
  if (!data) return <div>Loading...</div>

  const { writeup, user } = data

  if (!writeup) {
    return <div className="error">Writeup not found</div>
  }

  return (
    <div className="writeup-page">
      <WriteupDisplay writeup={writeup} user={user} />
    </div>
  )
}

export default Writeup
