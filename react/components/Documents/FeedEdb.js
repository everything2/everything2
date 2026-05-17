import React from 'react'

/**
 * FeedEdb - Admin tool for simulating EDB borg status.
 * Styles in CSS: .feed-edb__*
 * Allows admins to test/debug borg functionality.
 */
const FeedEdb = ({ data }) => {
  const {
    is_admin,
    message,
    current_count,
    action_taken,
    borg_options
  } = data

  const nodeId = window.e2?.node_id || ''

  if (!is_admin) {
    return (
      <div className="feed-edb">
        <p>{message}</p>
      </div>
    )
  }

  return (
    <div className="feed-edb">
      <p>
        <strong>Your current borged count:</strong> {current_count}
      </p>

      {action_taken ? (
        <div className="feed-edb__action-result">
          <p>{message}</p>
          <p>
            <a href={`?node_id=${nodeId}`} className="feed-edb__link">
              EDB still hungry
            </a>
          </p>
        </div>
      ) : (
        <div className="feed-edb__instructions">
          <p>
            This is mainly for the 3 of us that need to play with EDB.
          </p>
          <p>
            Er, that doesn&apos;t quite sound the way I meant it. How about &quot;...want to
            experiment with EDB&quot;.
          </p>
          <p>
            Mmmmm, that isn&apos;t quite what I meant, either. Lets try: &quot;...want to have
            EDB eat them&quot;.
          </p>
          <p>Argh, I give up.</p>

          <div className="feed-edb__options-row">
            <code>numborgings = ( </code>
            {borg_options.map((opt, idx) => (
              <span key={opt}>
                {idx > 0 && ', '}
                <a
                  href={`?node_id=${nodeId}&numborgings=${opt}&lastnode_id=0`}
                  className="feed-edb__option-link"
                >
                  {opt}
                </a>
              </span>
            ))}
            <code> );</code>
          </div>
        </div>
      )}
    </div>
  )
}

export default FeedEdb
