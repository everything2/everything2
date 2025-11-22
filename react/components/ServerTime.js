import React from 'react'

const ServerTime = ({ timeString, showLocalTime, localTimeString }) => {
  if (!timeString) return null

  return (
    <>
      <strong>Server time:</strong> {timeString}
      {showLocalTime && localTimeString && (
        <>
          <br />
          <strong>Your time:</strong> {localTimeString}
        </>
      )}
    </>
  )
}

export default ServerTime
