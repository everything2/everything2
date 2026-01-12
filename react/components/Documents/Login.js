import React from 'react'
import LoginForm from '../LoginForm'

const Login = ({ data }) => {
  const { state, message, siteName, user, defaultNode, lastNode } = data

  // Success state - just logged in successfully
  if (state === 'success') {
    return (
      <div style={styles.container}>
        <h2 style={styles.heading}>Welcome back!</h2>
        <p style={styles.text}>
          Hey, glad you're back! Where would you like to go?
        </p>
        <div style={styles.linkList}>
          <a
            href={`/user/${encodeURIComponent(user.title)}`}
            style={styles.primaryLink}
          >
            Go to your home node
          </a>
          <a
            href={defaultNode ? `/title/${encodeURIComponent(defaultNode.title)}` : '/'}
            style={styles.secondaryLink}
          >
            Go to {defaultNode ? defaultNode.title : 'the homepage'}
          </a>
          {lastNode && (
            <a
              href={`/title/${encodeURIComponent(lastNode.title)}`}
              style={styles.tertiaryLink}
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
      <div style={styles.container}>
        <h2 style={styles.heading}>Already logged in</h2>
        <p style={styles.text}>
          Hey, <a href={`/user/${encodeURIComponent(user.title)}`} style={styles.inlineLink}>{user.title}</a>... you're already logged in!
        </p>
      </div>
    )
  }

  // Login form (default or error state)
  const hasError = state === 'error'
  const welcomeMessage = hasError
    ? 'Oops. You must have the wrong login or password.'
    : `Welcome to ${siteName}. Sign in to continue:`

  return (
    <div style={{
      ...styles.container,
      borderLeft: hasError ? '4px solid #8b0000' : '4px solid #4060b0'
    }}>
      <h2 style={styles.heading}>Sign In</h2>

      <p style={{
        ...styles.text,
        color: hasError ? '#8b0000' : '#507898',
        fontWeight: hasError ? '500' : 'normal',
        marginBottom: '24px'
      }}>
        {welcomeMessage}
      </p>

      <LoginForm
        autoFocus={true}
        showForgotPassword={true}
      />

      <div style={styles.footer}>
        <p style={{ margin: 0 }}>
          Don't have an account?{' '}
          <a href="/title/Sign%20Up" style={styles.inlineLink}>Create one</a>!
        </p>
      </div>
    </div>
  )
}

const styles = {
  container: {
    maxWidth: '500px',
    margin: '40px auto',
    padding: '40px',
    backgroundColor: '#f8f9f9',
    borderRadius: '8px',
    boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
    borderLeft: '4px solid #38495e'
  },
  heading: {
    color: '#333333',
    marginTop: 0,
    marginBottom: '16px',
    fontSize: '28px',
    fontWeight: '600'
  },
  text: {
    fontSize: '16px',
    lineHeight: '1.6',
    color: '#111111',
    marginBottom: '20px'
  },
  linkList: {
    display: 'flex',
    flexDirection: 'column',
    gap: '12px'
  },
  primaryLink: {
    display: 'block',
    padding: '12px 20px',
    backgroundColor: '#4060b0',
    color: 'white',
    textDecoration: 'none',
    borderRadius: '4px',
    textAlign: 'center',
    fontWeight: '500'
  },
  secondaryLink: {
    display: 'block',
    padding: '12px 20px',
    backgroundColor: '#507898',
    color: 'white',
    textDecoration: 'none',
    borderRadius: '4px',
    textAlign: 'center',
    fontWeight: '500'
  },
  tertiaryLink: {
    display: 'block',
    padding: '12px 20px',
    backgroundColor: '#c5cdd7',
    color: '#111111',
    textDecoration: 'none',
    borderRadius: '4px',
    textAlign: 'center',
    fontWeight: '500'
  },
  inlineLink: {
    color: '#4060b0',
    textDecoration: 'none',
    fontWeight: '500'
  },
  footer: {
    paddingTop: '20px',
    marginTop: '20px',
    borderTop: '1px solid #d3d3d3',
    textAlign: 'center',
    fontSize: '14px',
    color: '#507898'
  }
}

export default Login
