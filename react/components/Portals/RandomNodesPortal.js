import NodeletPortal from './NodeletPortal'

class RandomNodesPortal extends NodeletPortal {
  constructor(props) {
    super(props)
    this.insertRoot = document.getElementById('randomnodes')
  }
}

export default RandomNodesPortal
