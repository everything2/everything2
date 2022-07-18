import NodeletPortal from './NodeletPortal'

class VitalsPortal extends NodeletPortal {
  constructor(props) {
    super(props)
    this.insertRoot = document.getElementById('vitals')
  }
}

export default VitalsPortal
