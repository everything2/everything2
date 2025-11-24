import NodeletPortal from './NodeletPortal'

class NoteletPortal extends NodeletPortal {
  constructor(props) {
    super(props)
    this.insertRoot = document.getElementById('notelet')
  }
}

export default NoteletPortal
