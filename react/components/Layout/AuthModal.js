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

  const handleBackdropClick = (e) => {
    if (e.target === e.currentTarget) {
      onClose()
    }
  }

  return (
    <div className="nodelet-modal-overlay" onClick={handleBackdropClick}>
      <div className="auth-modal" onClick={e => e.stopPropagation()}>
        <button
          type="button"
          className="auth-modal__close"
          onClick={onClose}
          aria-label="Close"
        >
          <FaTimes />
        </button>

        <div className="auth-modal__tabs">
          <button
            type="button"
            className={`auth-modal__tab${activeTab === 'login' ? ' auth-modal__tab--active' : ''}`}
            onClick={() => setActiveTab('login')}
          >
            Log In
          </button>
          <button
            type="button"
            className={`auth-modal__tab${activeTab === 'signup' ? ' auth-modal__tab--active' : ''}`}
            onClick={() => setActiveTab('signup')}
          >
            Sign Up
          </button>
        </div>

        {signupSuccess ? (
          <div className="auth-modal__success">
            <h3>Welcome, {signupSuccess.username}!</h3>
            <p>
              Your account has been created. Check your email ({signupSuccess.email}) for an activation link.
            </p>
            <p>
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

export default AuthModal
