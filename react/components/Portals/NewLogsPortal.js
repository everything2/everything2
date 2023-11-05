import NodeletPortal from './NodeletPortal'

class NewLogsPortal extends NodeletPortal {
  constructor(props) {
    super(props)
    this.insertRoot = document.getElementById('newlogs')
  }
}

export default NewLogsPortal
