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

  return (
    <Modal
      isOpen={isOpen}
      onRequestClose={onClose}
      style={modalStyles}
      contentLabel={title}
    >
      <div style={styles.container}>
        <h3 style={styles.title}>{title}</h3>
        <p style={styles.message}>{message}</p>
        <div style={styles.buttonRow}>
          <button
            type="button"
            onClick={onClose}
            style={styles.cancelButton}
            disabled={isSubmitting}
          >
            {cancelLabel}
          </button>
          <button
            type="button"
            onClick={handleConfirm}
            style={confirmStyle === 'danger' ? styles.dangerButton : styles.confirmButton}
            disabled={isSubmitting}
          >
            {isSubmitting ? 'Processing...' : confirmLabel}
          </button>
        </div>
      </div>
    </Modal>
  )
}

const modalStyles = {
  overlay: {
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    zIndex: 1000
  },
  content: {
    top: '50%',
    left: '50%',
    right: 'auto',
    bottom: 'auto',
    marginRight: '-50%',
    transform: 'translate(-50%, -50%)',
    padding: 0,
    border: 'none',
    borderRadius: '8px',
    maxWidth: '400px',
    width: '90%'
  }
}

const styles = {
  container: {
    padding: '20px'
  },
  title: {
    margin: '0 0 16px 0',
    fontSize: '18px',
    fontWeight: 'bold',
    color: '#38495e'
  },
  message: {
    margin: '0 0 20px 0',
    fontSize: '14px',
    color: '#495057',
    lineHeight: '1.5'
  },
  buttonRow: {
    display: 'flex',
    justifyContent: 'flex-end',
    gap: '10px'
  },
  cancelButton: {
    padding: '8px 16px',
    fontSize: '14px',
    backgroundColor: '#f8f9fa',
    border: '1px solid #dee2e6',
    borderRadius: '4px',
    cursor: 'pointer',
    color: '#495057'
  },
  confirmButton: {
    padding: '8px 16px',
    fontSize: '14px',
    backgroundColor: '#4060b0',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
    color: '#fff'
  },
  dangerButton: {
    padding: '8px 16px',
    fontSize: '14px',
    backgroundColor: '#dc3545',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
    color: '#fff'
  }
}

export default ConfirmActionModal
