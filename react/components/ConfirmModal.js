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
  cancelText = 'Cancel',
  confirmColor = '#667eea'
}) => {
  if (!isOpen) return null

  const handleConfirm = () => {
    onConfirm()
    onClose()
  }

  return (
    <div
      style={{
        position: 'fixed',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        backgroundColor: 'rgba(0, 0, 0, 0.5)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        zIndex: 10000,
        padding: '20px'
      }}
      onClick={onClose}
    >
      <div
        style={{
          backgroundColor: '#fff',
          borderRadius: '8px',
          padding: '24px',
          maxWidth: '400px',
          width: '100%',
          boxShadow: '0 4px 6px rgba(0, 0, 0, 0.1)',
          position: 'relative'
        }}
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div style={{
          marginBottom: '16px',
          borderBottom: `2px solid ${confirmColor}`,
          paddingBottom: '12px'
        }}>
          <h3 style={{ margin: 0, color: confirmColor, fontSize: '18px' }}>
            {title}
          </h3>
        </div>

        {/* Message */}
        <div style={{
          marginBottom: '24px',
          fontSize: '14px',
          color: '#333',
          lineHeight: '1.5'
        }}>
          {message}
        </div>

        {/* Buttons */}
        <div style={{
          display: 'flex',
          gap: '12px',
          justifyContent: 'flex-end'
        }}>
          <button
            type="button"
            onClick={onClose}
            style={{
              padding: '8px 16px',
              fontSize: '13px',
              border: '1px solid #dee2e6',
              borderRadius: '4px',
              backgroundColor: '#fff',
              color: '#495057',
              cursor: 'pointer'
            }}
          >
            {cancelText}
          </button>
          <button
            type="button"
            onClick={handleConfirm}
            style={{
              padding: '8px 16px',
              fontSize: '13px',
              border: 'none',
              borderRadius: '4px',
              backgroundColor: confirmColor,
              color: '#fff',
              cursor: 'pointer',
              fontWeight: 'bold'
            }}
          >
            {confirmText}
          </button>
        </div>
      </div>
    </div>
  )
}

export default ConfirmModal
