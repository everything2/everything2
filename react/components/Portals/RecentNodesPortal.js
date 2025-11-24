import NodeletPortal from './NodeletPortal'

class RecentNodesPortal extends NodeletPortal {
  constructor(props) {
    super(props)
    this.insertRoot = document.getElementById('recentnodes')
  }
}

export default RecentNodesPortal
