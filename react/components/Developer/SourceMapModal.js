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

// Centering is handled by the flex overlay (.nodelet-modal-overlay); no inline
// positioning needed. The old absolute-centering (top/left/transform) fought the
// flex centering and pushed the modal off the top of the screen.

export default SourceMapModal
