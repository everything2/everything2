import NodeletPortal from './NodeletPortal'

class NotificationsPortal extends NodeletPortal {
  constructor(props) {
    super(props)
    this.insertRoot = document.getElementById('notifications')
  }
}

export default NotificationsPortal
