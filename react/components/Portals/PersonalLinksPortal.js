import NodeletPortal from './NodeletPortal'

class PersonalLinksPortal extends NodeletPortal {
  constructor(props) {
    super(props)
    this.insertRoot = document.getElementById('personallinks')
  }
}

export default PersonalLinksPortal
