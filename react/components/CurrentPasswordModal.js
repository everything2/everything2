import React, { useState, useEffect } from 'react'
import Modal from 'react-modal'

/**
 * CurrentPasswordModal - asks for the user's current password before a password or email
 * change is saved (#4637). Shared by the Settings profile tab and the profile editor.
 *
 * Props:
 *   isOpen       - controls visibility
 *   onClose      - cancel / dismiss
 *   onConfirm    - called with the entered password
 *   changing     - what is being changed: 'password', 'email' or 'password and email'
 *   isSubmitting - keeps the modal open in a busy state while the save runs
 *   error        - message to show (e.g. a wrong current password), keeps the modal open
 */
const CurrentPasswordModal = ({ isOpen, onClose, onConfirm, changing = 'password', isSubmitting = false, error = null }) => {
  const [password, setPassword] = useState('')

  // Start empty each time it opens; the password never outlives the dialog.
  useEffect(() => {
    if (isOpen) setPassword('')
  }, [isOpen])

  const handleSubmit = (e) => {
    e.preventDefault()
    if (isSubmitting || !password) return
    onConfirm(password)
  }

  return (
    <Modal
      isOpen={isOpen}
      onRequestClose={isSubmitting ? undefined : onClose}
      style={modalStyles}
      contentLabel="Confirm your current password"
      className="modal-compact modal-compact--centered"
      overlayClassName="nodelet-modal-overlay"
    >
      <form className="modal-compact__content" onSubmit={handleSubmit}>
        <h3 className="modal-compact__title">Confirm it&apos;s you</h3>
        <p className="modal-compact__message">
          To change your {changing}, enter your current password.
        </p>
        <label className="modal-compact__label" htmlFor="current-password-modal-input">
          Current password
        </label>
        <input
          id="current-password-modal-input"
          type="password"
          name="current_password"
          autoComplete="current-password"
          className="modal-compact__input"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          disabled={isSubmitting}
          autoFocus
        />
        {error && (
          <div className="modal-compact__status modal-compact__status--error" role="alert">
            {error}
          </div>
        )}
        <div className="modal-compact__btn-row">
          <button
            type="button"
            onClick={onClose}
            className="modal-compact__btn modal-compact__btn--secondary modal-compact__btn--inline"
            disabled={isSubmitting}
          >
            Cancel
          </button>
          <button
            type="submit"
            className="modal-compact__btn modal-compact__btn--inline"
            disabled={isSubmitting || !password}
          >
            {isSubmitting ? 'Saving...' : 'Confirm'}
          </button>
        </div>
      </form>
    </Modal>
  )
}

// Same positioning as ConfirmActionModal: react-modal drops its default content styles when a
// className is given, so position must be set here or the modal falls into the overlay's flow
// and the transform pushes it off-screen on mobile (#4139).
const modalStyles = {
  overlay: {},
  content: {
    position: 'absolute',
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

/** What a pending change touches, for the modal's wording. */
export const describeCredentialChange = (passwordChanging, emailChanging) =>
  passwordChanging && emailChanging ? 'password and email'
    : emailChanging ? 'email'
      : 'password'

export default CurrentPasswordModal
