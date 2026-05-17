import React from 'react'

/**
 * GoOutside - Moves user to the "outside" room (room 0).
 * Displays result message after the action is performed.
 * Styles in CSS: .go-outside__*
 */
const GoOutside = ({ data }) => {
  const { success, locked_in, remaining_time, message } = data

  return (
    <div className="go-outside">
      {locked_in ? (
        <div className="go-outside__error-box">
          <p className="go-outside__warning-text">
            <strong>You cannot change rooms for {remaining_time} minutes.</strong>
          </p>
          <p>You can still send private messages, however, or talk to people in your current room.</p>
        </div>
      ) : success ? (
        <div className="go-outside__success-box">
          <p>{message}</p>
        </div>
      ) : (
        <div className="go-outside__error-box">
          <p>{message}</p>
        </div>
      )}
    </div>
  )
}

export default GoOutside
