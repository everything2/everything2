import NodeletPortal from './NodeletPortal'

class CategoriesPortal extends NodeletPortal {
  constructor(props) {
    super(props)
    this.insertRoot = document.getElementById('categories')
  }
}

export default CategoriesPortal
