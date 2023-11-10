import NodeletPortal from './NodeletPortal'

class SignInPortal extends NodeletPortal {
  constructor(props) {
    super(props)
    this.insertRoot = document.getElementById('signin')
  }
}

export default SignInPortal
