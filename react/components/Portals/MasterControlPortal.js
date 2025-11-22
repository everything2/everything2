import ReactDOM from 'react-dom'

const MasterControlPortal = ({ children }) => {
  const target = document.getElementById('mastercontrol')
  if (!target) return null

  return ReactDOM.createPortal(children, target)
}

export default MasterControlPortal
