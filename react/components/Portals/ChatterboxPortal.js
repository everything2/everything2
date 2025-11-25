import NodeletPortal from './NodeletPortal'

class ChatterboxPortal extends NodeletPortal {
  constructor(props) {
    super(props)
    this.insertRoot = document.getElementById('chatterbox')
  }
}

export default ChatterboxPortal
