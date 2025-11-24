import NodeletPortal from './NodeletPortal'

class MostWantedPortal extends NodeletPortal {
  constructor(props) {
    super(props)
    this.insertRoot = document.getElementById('mostwanted')
  }
}

export default MostWantedPortal
