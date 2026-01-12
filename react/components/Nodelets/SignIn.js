import React from 'react'
import NodeletContainer from '../NodeletContainer'
import LoginForm from '../LoginForm'

const SignIn = (props) => {
  let content = null

  if (!props.user.guest) {
    content = (
      <div style={{
        padding: '16px',
        textAlign: 'center',
        fontSize: '12px',
        fontStyle: 'italic',
        color: '#495057'
      }}>
        You are already signed in!
      </div>
    )
  } else {
    content = (
      <LoginForm
        nodelet={true}
        autoFocus={false}
        loginMessage={props.loginMessage}
        showForgotPassword={true}
        showSignUpLink={true}
      />
    )
  }

  return (
    <NodeletContainer
      id={props.id}
      title="Sign In"
      nodeletIsOpen={props.nodeletIsOpen}
    >
      {content}
    </NodeletContainer>
  )
}

export default SignIn
