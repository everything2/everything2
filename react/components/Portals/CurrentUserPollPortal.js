import NodeletPortal from './NodeletPortal'

class CurrentUserPollPortal extends NodeletPortal {
  constructor(props) {
    super(props)
    this.insertRoot = document.getElementById('currentuserpoll')
  }
}

export default CurrentUserPollPortal
