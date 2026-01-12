import React, { useState, useEffect } from 'react'
import { FaTimes } from 'react-icons/fa'
import LoginForm from '../LoginForm'
import SignUpForm from '../SignUpForm'

/**
 * AuthModal - Unified login/signup modal
 *
 * A tabbed modal for authentication that replaces the sign-in nodelet site-wide.
 * Keeps users in context instead of navigating to separate pages.
 *
 * @param {function} onClose - Called when modal should close
 * @param {string} initialTab - 'login' or 'signup' (default: 'login')
 * @param {boolean} useRecaptcha - Whether to require reCAPTCHA for signup
 * @param {string} recaptchaKey - reCAPTCHA v3 public key
 */
const AuthModal = ({ onClose, initialTab = 'login', useRecaptcha = false, recaptchaKey = '' }) => {
  const [activeTab, setActiveTab] = useState(initialTab)
  const [signupSuccess, setSignupSuccess] = useState(null)

  // Close on escape key
  useEffect(() => {
    const handleEscape = (e) => {
      if (e.key === 'Escape') onClose()
    }
    document.addEventListener('keydown', handleEscape)
    return () => document.removeEventListener('keydown', handleEscape)
  }, [onClose])

  // Prevent body scroll when modal is open
  useEffect(() => {
    document.body.style.overflow = 'hidden'
    return () => {
      document.body.style.overflow = ''
    }
  }, [])

  const handleSignupSuccess = ({ username, linkValid, email }) => {
    setSignupSuccess({ username, linkValid, email })
  }

  return (
    <div style={styles.overlay} onClick={onClose}>
      <div style={styles.modal} onClick={e => e.stopPropagation()}>
        <button
          type="button"
          style={styles.closeButton}
          onClick={onClose}
          aria-label="Close"
        >
          <FaTimes />
        </button>

        <div style={styles.tabs}>
          <button
            type="button"
            style={{
              ...styles.tab,
              ...(activeTab === 'login' ? styles.tabActive : {})
            }}
            onClick={() => setActiveTab('login')}
          >
            Log In
          </button>
          <button
            type="button"
            style={{
              ...styles.tab,
              ...(activeTab === 'signup' ? styles.tabActive : {})
            }}
            onClick={() => setActiveTab('signup')}
          >
            Sign Up
          </button>
        </div>

        {signupSuccess ? (
          <div style={styles.successMessage}>
            <h3 style={{ margin: '0 0 12px 0', color: '#38495e' }}>Welcome, {signupSuccess.username}!</h3>
            <p style={{ margin: '0 0 8px 0' }}>
              Your account has been created. Check your email ({signupSuccess.email}) for an activation link.
            </p>
            <p style={{ margin: 0, fontSize: '14px', color: '#666' }}>
              The link will expire in {signupSuccess.linkValid} days.
            </p>
          </div>
        ) : activeTab === 'login' ? (
          <LoginForm compact={true} autoFocus={true} />
        ) : (
          <SignUpForm
            useRecaptcha={useRecaptcha}
            recaptchaKey={recaptchaKey}
            onSuccess={handleSignupSuccess}
            compact={true}
            showConfirmEmail={false}
          />
        )}
      </div>
    </div>
  )
}

const styles = {
  overlay: {
    position: 'fixed',
    inset: 0,
    backgroundColor: 'rgba(0,0,0,0.5)',
    zIndex: 1002,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    padding: '20px'
  },
  modal: {
    backgroundColor: 'white',
    width: '100%',
    maxWidth: '400px',
    borderRadius: '12px',
    padding: '24px',
    position: 'relative'
  },
  closeButton: {
    position: 'absolute',
    top: '12px',
    right: '12px',
    background: 'none',
    border: 'none',
    color: '#507898',
    fontSize: '20px',
    cursor: 'pointer',
    padding: '4px',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center'
  },
  tabs: {
    display: 'flex',
    marginBottom: '20px',
    borderBottom: '2px solid #e0e0e0'
  },
  tab: {
    flex: 1,
    background: 'none',
    border: 'none',
    padding: '12px',
    fontSize: '16px',
    fontWeight: 500,
    color: '#507898',
    cursor: 'pointer',
    borderBottom: '2px solid transparent',
    marginBottom: '-2px'
  },
  tabActive: {
    color: '#4060b0',
    borderBottom: '2px solid #4060b0'
  },
  successMessage: {
    backgroundColor: '#e8f5e9',
    border: '1px solid #a5d6a7',
    borderRadius: '8px',
    padding: '16px',
    textAlign: 'center'
  }
}

export default AuthModal
