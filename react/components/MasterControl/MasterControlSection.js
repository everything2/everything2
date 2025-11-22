import React, { useState } from 'react'

const MasterControlSection = ({ title, children, initiallyOpen = true, sectionId }) => {
  const [isOpen, setIsOpen] = useState(initiallyOpen)

  return (
    <div id={sectionId} className="nodeletsection">
      <div className="sectionheading">
        <tt> {isOpen ? '-' : '+'} </tt>
        <button
          onClick={() => setIsOpen(!isOpen)}
          style={{
            background: 'none',
            border: 'none',
            padding: 0,
            cursor: 'pointer',
            textDecoration: 'underline'
          }}
        >
          <strong>{title}</strong>
        </button>
      </div>
      {isOpen && <div className="sectioncontent">{children}</div>}
    </div>
  )
}

export default MasterControlSection
