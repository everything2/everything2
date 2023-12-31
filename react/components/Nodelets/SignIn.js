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
    content = <em>You are already signed in!</em>
  }else{
    content = <><form method="POST" name="loginform" id="loginform" action="/?trylogin=1" >
      <input type="hidden" name="node_id" value={props.loginGoto} />
      {lastnode_form_field}
      <input type="hidden" name="op" value="login" />
      <table border="0">
      <tbody>
      <tr>
      <td><strong>Login</strong></td>
      <td><input type="text" name="user" size="10" maxLength="20" tabIndex="1" autoComplete="username" /></td>
      </tr>
      <tr>
      <td><strong>Password</strong></td>
      <td><input type="password" name="passwd" size="10" maxLength="240" tabIndex="2" autoComplete="current-password" /></td>
      </tr>
      </tbody>
      </table><font size="2"><input type="checkbox" id="signin_expires" name="expires" defaultChecked={false} value="+10y" tabIndex="3" /><label htmlFor="signin_expires">Remember me</label></font>
      <p><strong><LinkNode title="Reset password" type="superdoc" display="Lost password" /></strong></p>
      <p><strong><LinkNode title="Sign Up" type="superdoc" /></strong></p>
      <input type="submit" name="login" value="Login" tabIndex="4" /><br />
      {props.loginMessage}
    </form>
    <p>Need help? <a href="mailto:accounthelp@everything2.com">accounthelp@everything2.com</a></p></>
  }

  return <NodeletContainer title="Sign In" nodeletIsOpen={props.nodeletIsOpen}>{content}</NodeletContainer>

}

export default SignIn;
