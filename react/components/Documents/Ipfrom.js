import React from 'react'

/**
 * Ipfrom - IP address lookup page
 *
 * Shows the user's IP address as detected by the server
 */
const Ipfrom = ({ data }) => {
  const { ip } = data || {}

  return (
    <div className="document">
      <p>
        Looks like you're coming from <strong>{ip || 'unknown'}</strong>
      </p>
      <p>Hope that helps.</p>
    </div>
  )
}

export default Ipfrom
