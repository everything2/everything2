import React from 'react'

/**
 * FeedEdb - Admin tool for simulating EDB borg status.
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
      <div style={styles.container}>
        <p>{message}</p>
      </div>
    )
  }

  return (
    <div style={styles.container}>
      <p>
        <strong>Your current borged count:</strong> {current_count}
      </p>

      {action_taken ? (
        <div style={styles.actionResult}>
          <p>{message}</p>
          <p>
            <a href={`?node_id=${nodeId}`} style={styles.link}>
              EDB still hungry
            </a>
          </p>
        </div>
      ) : (
        <div style={styles.instructions}>
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

          <div style={styles.optionsRow}>
            <code>numborgings = ( </code>
            {borg_options.map((opt, idx) => (
              <span key={opt}>
                {idx > 0 && ', '}
                <a
                  href={`?node_id=${nodeId}&numborgings=${opt}&lastnode_id=0`}
                  style={styles.optionLink}
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

const styles = {
  container: {
    padding: '10px',
    fontSize: '13px',
    lineHeight: '1.5',
    color: '#111'
  },
  actionResult: {
    marginTop: '15px',
    padding: '10px',
    backgroundColor: '#f8f9f9',
    borderRadius: '4px'
  },
  instructions: {
    marginTop: '15px'
  },
  optionsRow: {
    marginTop: '15px',
    fontFamily: 'monospace'
  },
  link: {
    color: '#4060b0',
    textDecoration: 'none'
  },
  optionLink: {
    color: '#4060b0',
    textDecoration: 'none',
    padding: '2px 6px',
    backgroundColor: '#f0f0f0',
    borderRadius: '3px',
    margin: '0 2px'
  }
}

export default FeedEdb
