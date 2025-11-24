import React from 'react'
import ReactDOM from 'react-dom'
import Messages from '../Nodelets/Messages'

const MessagesPortal = (props) => {
  const container = document.getElementById('messages_messages')

  if (!container) {
    return null
  }

  return ReactDOM.createPortal(
    <Messages {...props} />,
    container
  )
}

export default MessagesPortal
