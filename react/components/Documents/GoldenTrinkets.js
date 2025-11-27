import React from 'react'
import LinkNode from '../LinkNode'

/**
 * Golden Trinkets - Display user's karma (blessings received)
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
    <div className="golden-trinkets" style={{ padding: '40px 20px', textAlign: 'center' }}>
      <div style={{ fontSize: '16px', marginBottom: '40px' }}>
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
        <div
          style={{
            marginTop: '40px',
            padding: '20px',
            backgroundColor: '#f8f9fa',
            border: '1px solid #dee2e6',
            borderRadius: '5px',
            maxWidth: '500px',
            margin: '40px auto'
          }}
        >
          <h3 style={{ marginTop: 0 }}>Admin Lookup</h3>

          <form method="GET">
            <div style={{ marginBottom: '10px' }}>
              <input
                type="text"
                name="for_user"
                placeholder="Enter username"
                defaultValue=""
                style={{
                  padding: '8px 12px',
                  fontSize: '14px',
                  border: '1px solid #dee2e6',
                  borderRadius: '3px',
                  width: '200px'
                }}
              />
              <button
                type="submit"
                style={{
                  marginLeft: '10px',
                  padding: '8px 16px',
                  fontSize: '14px',
                  fontWeight: 'bold',
                  color: '#fff',
                  backgroundColor: '#38495e',
                  border: 'none',
                  borderRadius: '3px',
                  cursor: 'pointer'
                }}
              >
                Lookup
              </button>
            </div>
          </form>

          {error && (
            <div
              style={{
                marginTop: '10px',
                padding: '10px',
                backgroundColor: '#fff3cd',
                border: '1px solid #ffc107',
                borderRadius: '3px',
                color: '#856404'
              }}
            >
              <em>{error}</em>
            </div>
          )}

          {forUser && (
            <div
              style={{
                marginTop: '10px',
                padding: '10px',
                backgroundColor: '#d4edda',
                border: '1px solid #c3e6cb',
                borderRadius: '3px',
                color: '#155724'
              }}
            >
              <LinkNode title={forUser.username} type="user" />'s karma: {forUser.karma}
            </div>
          )}
        </div>
      )}
    </div>
  )
}

export default GoldenTrinkets
