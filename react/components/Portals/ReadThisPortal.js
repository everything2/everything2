import NodeletPortal from './NodeletPortal'

class ReadThisPortal extends NodeletPortal {
  constructor(props) {
    super(props)
    this.insertRoot = document.getElementById('readthis')
  }
}

export default ReadThisPortal
