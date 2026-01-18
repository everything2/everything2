import React from 'react'
import LoginForm from '../LoginForm'

const Login = ({ data }) => {
  const { state, message, siteName, user, defaultNode, lastNode } = data

  // Success state - just logged in successfully
  if (state === 'success') {
    return (
      <div className="login-page login-page--success">
        <h2 className="login-page__heading">Welcome back!</h2>
        <p className="login-page__text">
          Hey, glad you're back! Where would you like to go?
        </p>
        <div className="login-page__link-list">
          <a
            href={`/user/${encodeURIComponent(user.title)}`}
            className="login-page__link login-page__link--primary"
          >
            Go to your home node
          </a>
          <a
            href={defaultNode ? `/title/${encodeURIComponent(defaultNode.title)}` : '/'}
            className="login-page__link login-page__link--secondary"
          >
            Go to {defaultNode ? defaultNode.title : 'the homepage'}
          </a>
          {lastNode && (
            <a
              href={`/title/${encodeURIComponent(lastNode.title)}`}
              className="login-page__link login-page__link--tertiary"
            >
              Go back to {lastNode.title}
            </a>
          )}
        </div>
      </div>
    )
  }

  // Already logged in state
  if (state === 'already_logged_in') {
    return (
      <div className="login-page">
        <h2 className="login-page__heading">Already logged in</h2>
        <p className="login-page__text">
          Hey, <a href={`/user/${encodeURIComponent(user.title)}`} className="login-page__inline-link">{user.title}</a>... you're already logged in!
        </p>
      </div>
    )
  }

  // Login form (default or error state)
  const hasError = state === 'error'
  const welcomeMessage = hasError
    ? 'Oops. You must have the wrong login or password.'
    : `Welcome to ${siteName}. Sign in to continue:`

  const containerClass = hasError ? 'login-page login-page--error' : 'login-page'
  const textClass = hasError ? 'login-page__text login-page__text--error' : 'login-page__text login-page__text--welcome'

  return (
    <div className={containerClass}>
      <h2 className="login-page__heading">Sign In</h2>

      <p className={textClass}>
        {welcomeMessage}
      </p>

      <LoginForm
        autoFocus={true}
        showForgotPassword={true}
      />

      <div className="login-page__footer">
        <p style={{ margin: 0 }}>
          Don't have an account?{' '}
          <a href="/title/Sign%20Up" className="login-page__inline-link">Create one</a>!
        </p>
      </div>
    </div>
  )
}

export default Login
