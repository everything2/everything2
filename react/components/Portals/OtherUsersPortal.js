import NodeletPortal from './NodeletPortal'

class OtherUsersPortal extends NodeletPortal {
  constructor(props) {
    super(props)
    this.insertRoot = document.getElementById('otherusers')
  }
}

export default OtherUsersPortal
