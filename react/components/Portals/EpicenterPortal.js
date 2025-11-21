import NodeletPortal from './NodeletPortal'

class EpicenterPortal extends NodeletPortal {
  constructor(props) {
    super(props)
    this.insertRoot = document.getElementById('epicenter')
  }
}

export default EpicenterPortal
