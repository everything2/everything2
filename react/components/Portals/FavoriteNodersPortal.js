import NodeletPortal from './NodeletPortal'

class FavoriteNodersPortal extends NodeletPortal {
  constructor(props) {
    super(props)
    this.insertRoot = document.getElementById('favoritenoders')
  }
}

export default FavoriteNodersPortal
