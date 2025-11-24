import NodeletPortal from './NodeletPortal'

class UsergroupWriteupsPortal extends NodeletPortal {
  constructor(props) {
    super(props)
    this.insertRoot = document.getElementById('usergroupwriteups')
  }
}

export default UsergroupWriteupsPortal
