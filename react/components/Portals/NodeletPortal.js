
import React from 'react'
import * as ReactDOM from 'react-dom'

class NodeletPortal extends React.Component {
  constructor(props) {
    super(props)
    this.el = document.createElement('div')
  }

  componentDidMount() {
    if(this.insertRoot != undefined)
    {
      this.insertRoot.appendChild(this.el)
    }
  }

  componentWillUnmount() {
    if(this.insertRoot != undefined)
    {
      this.insertRoot.removeChild(this.el)
    }
  }

  render() {
    if(this.insertRoot != undefined)
    {
      return ReactDOM.createPortal(
        this.props.children,
        this.el
      );
    }
  }
}

export default NodeletPortal
