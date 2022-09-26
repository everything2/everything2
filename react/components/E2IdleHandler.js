import { Component } from 'react'
import { withIdleTimer } from 'react-idle-timer'

class E2IdleHandlerComponent extends Component {
  render () {
    return this.props.children
  }
}

export const E2IdleHandler = withIdleTimer(E2IdleHandlerComponent)
