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
      className="modal-compact modal-compact--wide"
      overlayClassName="nodelet-modal-overlay"
      style={modalPositioning}
    >
      <div className="modal-compact__content">
        <SourceMapDisplay
          sourceMap={sourceMap}
          title={`Source Map: ${nodeTitle}`}
          showContributeBox={true}
          showDescription={true}
          showEmptyState={true}
        />

        <div className="modal-compact__btn-row mt-4">
          <button
            type="button"
            onClick={onClose}
            className="modal-compact__btn modal-compact__btn--secondary modal-compact__btn--inline"
          >
            Close
          </button>
        </div>
      </div>
    </Modal>
  )
}

// react-modal requires positioning styles as objects
const modalPositioning = {
  overlay: {},
  content: {
    top: '50%',
    left: '50%',
    right: 'auto',
    bottom: 'auto',
    marginRight: '-50%',
    transform: 'translate(-50%, -50%)',
    padding: 0,
    border: 'none'
  }
}

export default SourceMapModal
