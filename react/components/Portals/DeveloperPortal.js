
import NodeletPortal from './NodeletPortal'

class DeveloperPortal extends NodeletPortal {
  constructor(props) {
    super(props)
    this.insertRoot = document.getElementById('everythingdeveloper')
  }
}

export default DeveloperPortal
