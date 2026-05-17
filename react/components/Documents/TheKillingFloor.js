import React from 'react'

/**
 * The Killing Floor - Deprecated Editorial Tool
 *
 * Legacy editorial tool no longer used by the editing system.
 * Preserved for technical site integrity only.
 * Styles in CSS: .killing-floor__*
 */
const TheKillingFloor = ({ data }) => {
  const { title = 'The Killing Floor' } = data

  return (
    <div className="killing-floor">
      <div className="killing-floor__warning-box">
        <h3 className="killing-floor__warning-title">⚠️ Deprecated Feature</h3>
        <p className="killing-floor__warning-text">
          <strong>{title}</strong> is no longer in use by the editing system.
        </p>
        <p className="killing-floor__warning-text">
          This node has been preserved for technical site integrity, but its functionality
          is no longer necessary. If you are looking for editorial tools, please visit the
          Content Reports page or consult with site administrators.
        </p>
      </div>
    </div>
  )
}

export default TheKillingFloor
