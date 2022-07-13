import React from 'react'
import * as ReactDOM from 'react-dom'
class VitalsPortal extends React.Component {
  constructor(props) {
    super(props)
    this.insertRoot = document.getElementById('vitals')
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
    return ReactDOM.createPortal(
      this.props.children,
      this.el
    );
  }
}

export default VitalsPortal
