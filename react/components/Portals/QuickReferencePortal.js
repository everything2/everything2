import NodeletPortal from './NodeletPortal'

export default class QuickReferencePortal extends NodeletPortal {
  constructor(props) {
    super(props)
    this.insertRoot = document.getElementById('quickreference')
  }
}
