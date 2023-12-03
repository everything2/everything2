import NodeletPortal from './NodeletPortal'

export default class NeglectedDraftsPortal extends NodeletPortal {
  constructor(props) {
    super(props)
    this.insertRoot = document.getElementById('neglecteddrafts')
  }
}
