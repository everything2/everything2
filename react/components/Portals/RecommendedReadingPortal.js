import NodeletPortal from './NodeletPortal'

class RecommendedReadingPortal extends NodeletPortal {
  constructor(props) {
    super(props)
    this.insertRoot = document.getElementById('recommendedreading')
  }
}

export default RecommendedReadingPortal
