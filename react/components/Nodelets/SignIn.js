import React from 'react'
import LinkNode from '../LinkNode'
import NodeletContainer from '../NodeletContainer'

const SignIn = (props) => {
  let lastnode_form_field = <></>
  let content = <></>
  if (props.lastnodeId !== undefined)
  {
    lastnode_form_field = <input type="hidden" name="lastnode_id" value={props.lastnodeId} />
  }

  if(!props.user.guest)
  {
    content = <div style={{
      padding: '16px',
      textAlign: 'center',
      fontSize: '12px',
      fontStyle: 'italic',
      color: '#495057'
    }}>
      You are already signed in!
    </div>
  }else{
    content = <>
      <form method="POST" name="loginform" id="loginform" action="/?trylogin=1" style={{
        padding: '12px',
        backgroundColor: '#f8f9fa',
        borderRadius: '4px'
      }}>
        <input type="hidden" name="node_id" value={props.loginGoto} />
        {lastnode_form_field}
        <input type="hidden" name="op" value="login" />

        <div style={{ marginBottom: '12px' }}>
          <label htmlFor="signin_user" style={{
            display: 'block',
            marginBottom: '4px',
            fontSize: '12px',
            fontWeight: 'bold',
            color: '#495057'
          }}>
            Login
          </label>
          <input
            type="text"
            id="signin_user"
            name="user"
            maxLength="20"
            tabIndex="1"
            autoComplete="username"
            style={{
              width: '100%',
              padding: '6px 8px',
              fontSize: '12px',
              border: '1px solid #dee2e6',
              borderRadius: '3px',
              boxSizing: 'border-box'
            }}
          />
        </div>

        <div style={{ marginBottom: '12px' }}>
          <label htmlFor="signin_passwd" style={{
            display: 'block',
            marginBottom: '4px',
            fontSize: '12px',
            fontWeight: 'bold',
            color: '#495057'
          }}>
            Password
          </label>
          <input
            type="password"
            id="signin_passwd"
            name="passwd"
            maxLength="240"
            tabIndex="2"
            autoComplete="current-password"
            style={{
              width: '100%',
              padding: '6px 8px',
              fontSize: '12px',
              border: '1px solid #dee2e6',
              borderRadius: '3px',
              boxSizing: 'border-box'
            }}
          />
        </div>

        <div style={{ marginBottom: '12px' }}>
          <label htmlFor="signin_expires" style={{
            display: 'flex',
            alignItems: 'center',
            gap: '6px',
            fontSize: '12px',
            color: '#495057',
            cursor: 'pointer'
          }}>
            <input
              type="checkbox"
              id="signin_expires"
              name="expires"
              defaultChecked={false}
              value="+10y"
              tabIndex="3"
              style={{ cursor: 'pointer' }}
            />
            <span>Remember me</span>
          </label>
        </div>

        {props.loginMessage && (
          <div style={{
            marginBottom: '12px',
            padding: '8px',
            backgroundColor: '#fff',
            border: '1px solid #dee2e6',
            borderRadius: '3px',
            fontSize: '12px',
            color: '#dc3545'
          }}>
            {props.loginMessage}
          </div>
        )}

        <input
          type="submit"
          name="login"
          value="Login"
          tabIndex="4"
          style={{
            width: '100%',
            padding: '8px',
            fontSize: '12px',
            fontWeight: 'bold',
            color: '#fff',
            backgroundColor: '#38495e',
            border: 'none',
            borderRadius: '3px',
            cursor: 'pointer',
            marginBottom: '12px'
          }}
        />
      </form>

      <div style={{
        padding: '12px',
        display: 'flex',
        flexDirection: 'column',
        gap: '8px',
        fontSize: '12px'
      }}>
        <div><LinkNode title="Reset password" type="superdoc" display="Lost password?" /></div>
        <div><LinkNode title="Sign Up" type="superdoc" display="Create an account" /></div>
        <div style={{ marginTop: '4px', fontSize: '11px', color: '#6c757d' }}>
          Need help? <a href="mailto:accounthelp@everything2.com" style={{ color: '#5a9fd4' }}>accounthelp@everything2.com</a>
        </div>
      </div>
    </>
  }

  return <NodeletContainer id={props.id}
      title="Sign In" nodeletIsOpen={props.nodeletIsOpen}>{content}</NodeletContainer>

}

export default SignIn;
