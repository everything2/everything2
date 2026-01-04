import React from 'react'
import Modal from 'react-modal'
import SourceMapDisplay from './SourceMapDisplay'

/**
 * SourceMapModal - Modal wrapper for SourceMapDisplay
 *
 * Displays the source map in a modal dialog, reusing the
 * SourceMapDisplay component for consistent rendering.
 */
const SourceMapModal = ({ isOpen, onClose, sourceMap, nodeTitle }) => {
  return (
    <Modal
      isOpen={isOpen}
      onRequestClose={onClose}
      ariaHideApp={false}
      contentLabel="Source Map"
      style={{
        content: {
          top: '50%',
          left: '50%',
          right: 'auto',
          bottom: 'auto',
          marginRight: '-50%',
          transform: 'translate(-50%, -50%)',
          minWidth: '600px',
          maxWidth: '800px',
          maxHeight: '80vh',
          overflow: 'auto',
          padding: '0'
        },
      }}
    >
      <div style={{ padding: '20px' }}>
        <SourceMapDisplay
          sourceMap={sourceMap}
          title={`Source Map: ${nodeTitle}`}
          showContributeBox={true}
          showDescription={true}
          showEmptyState={true}
        />

        <div style={{ textAlign: 'right', marginTop: '20px' }}>
          <button
            type="button"
            onClick={onClose}
            style={{
              padding: '8px 20px',
              backgroundColor: '#6c757d',
              color: 'white',
              border: 'none',
              borderRadius: '4px',
              cursor: 'pointer',
              fontSize: '14px',
              fontWeight: '500'
            }}
          >
            Close
          </button>
        </div>
      </div>
    </Modal>
  )
}

export default SourceMapModal
