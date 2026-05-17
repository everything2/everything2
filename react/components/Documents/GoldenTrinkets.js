import React from 'react'
import LinkNode from '../LinkNode'

/**
 * Golden Trinkets - Display user's karma (blessings received)
 * Styles in CSS: .golden-trinkets__*
 *
 * Phase 4a migration from Mason template golden_trinkets.mc
 * Shows: User's karma count, admin lookup feature
 */
const GoldenTrinkets = ({ data, user }) => {
  const karma = data.karma || 0
  const isAdmin = Boolean(data.isAdmin)
  const forUser = data.forUser
  const error = data.error

  return (
    <div className="golden-trinkets">
      <div className="golden-trinkets__message">
        {karma === 0 ? (
          <em>You are not feeling very special.</em>
        ) : karma < 0 ? (
          <strong>You feel a burning sensation...</strong>
        ) : (
          <>
            You feel blessed -- every day, the gods see you and are glad -- you have collected {karma} of
            their <LinkNode title="bless" type="document" display="Golden Trinkets" />
          </>
        )}
      </div>

      {isAdmin && (
        <div className="golden-trinkets__admin-box">
          <h3 className="golden-trinkets__admin-title">Admin Lookup</h3>

          <form method="GET">
            <div className="golden-trinkets__form-row">
              <input
                type="text"
                name="for_user"
                placeholder="Enter username"
                defaultValue=""
                className="golden-trinkets__input"
              />
              <button
                type="submit"
                className="golden-trinkets__submit-btn"
              >
                Lookup
              </button>
            </div>
          </form>

          {error && (
            <div className="golden-trinkets__error-box">
              <em>{error}</em>
            </div>
          )}

          {forUser && (
            <div className="golden-trinkets__result-box">
              <LinkNode title={forUser.username} type="user" />'s karma: {forUser.karma}
            </div>
          )}
        </div>
      )}
    </div>
  )
}

export default GoldenTrinkets
