import NodeletPortal from './NodeletPortal'

class StatisticsPortal extends NodeletPortal {
  constructor(props) {
    super(props)
    this.insertRoot = document.getElementById('statistics')
  }
}

export default StatisticsPortal
