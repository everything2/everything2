import React from 'react'
import Modal from 'react-modal'

/**
 * ConfirmActionModal - Reusable confirmation dialog for destructive actions
 *
 * Replaces the legacy confirmop JavaScript pattern with a React modal.
 * Used for actions that require user confirmation before proceeding.
 *
 * Props:
 *   isOpen - Boolean controlling modal visibility
 *   onClose - Function called when user cancels or closes modal
 *   onConfirm - Function called when user confirms the action
 *   title - Modal title (e.g., "Confirm Delete")
 *   message - Description of what will happen (e.g., "Do you really want to delete this?")
 *   confirmLabel - Label for confirm button (default: "OK")
 *   cancelLabel - Label for cancel button (default: "Cancel")
 *   confirmStyle - Style variant for confirm button: "danger" (red) or "default" (blue)
 *   isSubmitting - Boolean to show loading state on confirm button
 */
const ConfirmActionModal = ({
  isOpen,
  onClose,
  onConfirm,
  title = 'Confirm',
  message,
  confirmLabel = 'OK',
  cancelLabel = 'Cancel',
  confirmStyle = 'danger',
  isSubmitting = false
}) => {
  const handleConfirm = (e) => {
    e.preventDefault()
    if (!isSubmitting) {
      onConfirm()
    }
  }

  const confirmBtnClass = confirmStyle === 'danger'
    ? 'modal-compact__btn modal-compact__btn--danger modal-compact__btn--inline'
    : 'modal-compact__btn modal-compact__btn--inline'

  return (
    <Modal
      isOpen={isOpen}
      onRequestClose={onClose}
      style={modalStyles}
      contentLabel={title}
      className="modal-compact modal-compact--centered"
      overlayClassName="nodelet-modal-overlay"
    >
      <div className="modal-compact__content">
        <h3 className="modal-compact__title">{title}</h3>
        <p className="modal-compact__message">{message}</p>
        <div className="modal-compact__btn-row">
          <button
            type="button"
            onClick={onClose}
            className="modal-compact__btn modal-compact__btn--secondary modal-compact__btn--inline"
            disabled={isSubmitting}
          >
            {cancelLabel}
          </button>
          <button
            type="button"
            onClick={handleConfirm}
            className={confirmBtnClass}
            disabled={isSubmitting}
          >
            {isSubmitting ? 'Processing...' : confirmLabel}
          </button>
        </div>
      </div>
    </Modal>
  )
}

// react-modal requires style objects for positioning, but we use CSS classes for everything else
const modalStyles = {
  overlay: {
    // Let CSS class handle styling via overlayClassName
  },
  content: {
    // Let CSS class handle styling via className
    // Only provide positioning overrides needed by react-modal
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

export default ConfirmActionModal
