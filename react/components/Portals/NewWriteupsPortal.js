import NodeletPortal from './NodeletPortal'

class NewWriteupsPortal extends NodeletPortal {
  constructor(props) {
    super(props)
    this.insertRoot = document.getElementById('newwriteups')
  }
}

export default NewWriteupsPortal
