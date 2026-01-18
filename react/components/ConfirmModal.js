import React from 'react'

/**
 * ConfirmModal - Simple confirmation dialog modal
 *
 * Used for confirming actions like voting and cooling when
 * the user has enabled safety settings.
 */
const ConfirmModal = ({
  isOpen,
  onClose,
  onConfirm,
  title = 'Confirm',
  message,
  confirmText = 'Confirm',
  cancelText = 'Cancel'
}) => {
  if (!isOpen) return null

  const handleConfirm = () => {
    onConfirm()
    onClose()
  }

  const handleBackdropClick = (e) => {
    if (e.target === e.currentTarget) {
      onClose()
    }
  }

  return (
    <div className="nodelet-modal-overlay" onClick={handleBackdropClick}>
      <div className="modal-compact modal-compact--centered">
        <div className="modal-compact__content">
          {/* Header */}
          <div className="modal-compact__header">
            <h3 className="modal-compact__title">{title}</h3>
          </div>

          {/* Message */}
          <div className="modal-compact__message">
            {message}
          </div>

          {/* Buttons */}
          <div className="modal-compact__btn-row">
            <button
              type="button"
              onClick={onClose}
              className="modal-compact__btn modal-compact__btn--secondary modal-compact__btn--inline"
            >
              {cancelText}
            </button>
            <button
              type="button"
              onClick={handleConfirm}
              className="modal-compact__btn modal-compact__btn--inline"
            >
              {confirmText}
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}

export default ConfirmModal
