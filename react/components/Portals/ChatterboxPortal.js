import React from 'react'
import ReactDOM from 'react-dom'
import Chatterbox from '../Nodelets/Chatterbox'

const ChatterboxPortal = (props) => {
  const container = document.getElementById('chatterbox')

  if (!container) {
    return null
  }

  return ReactDOM.createPortal(
    <Chatterbox {...props} />,
    container
  )
}

export default ChatterboxPortal
