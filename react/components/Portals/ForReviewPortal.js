import NodeletPortal from './NodeletPortal'

class ForReviewPortal extends NodeletPortal {
  constructor(props) {
    super(props)
    this.insertRoot = document.getElementById('forreview')
  }
}

export default ForReviewPortal
