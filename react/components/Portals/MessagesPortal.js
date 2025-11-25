import NodeletPortal from './NodeletPortal'

class MessagesPortal extends NodeletPortal {
  constructor(props) {
    super(props)
    this.insertRoot = document.getElementById('messages')
  }
}

export default MessagesPortal
