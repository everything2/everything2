import React from 'react'
import NodeletContainer from '../NodeletContainer'
import LoginForm from '../LoginForm'

const SignIn = (props) => {
  let content = null

  if (!props.user.guest) {
    content = (
      <div className="signin__already-logged-in">
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
