import React, { useState } from 'react'

/**
 * Noding Speedometer - Calculate user noding speed
 *
 * Calculates how fast a user is writing based on their last N writeups,
 * and projects when they'll reach the next level.
 */
const NodingSpeedometer = ({ data, e2 }) => {
  const {
    error,
    username: initialUsername = '',
    clock_nodes: initialClockNodes = 50,
    total_writeups,
    actual_count,
    days_elapsed,
    speed,
    color,
    width,
    comment,
    level_data
  } = data

  const [username, setUsername] = useState(initialUsername)
  const [clockNodes, setClockNodes] = useState(initialClockNodes)

  const handleSubmit = (e) => {
    e.preventDefault()
    // Construct the URL with the current path and new parameters
    const url = new URL(window.location.href)
    url.searchParams.set('speedyuser', username)
    url.searchParams.set('clocknodes', clockNodes)
    window.location.href = url.toString()
  }

  const hasResults = speed !== undefined

  return (
    <div style={styles.container}>
      <form method="POST" style={styles.form}>
        <input type="hidden" name="node_id" value={e2?.node_id || ''} />
        <table>
          <tbody>
            <tr>
              <td style={styles.label}>Username:</td>
              <td>
                <input
                  type="text"
                  name="speedyuser"
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  style={styles.input}
                />
              </td>
            </tr>
            <tr>
              <td style={styles.label}>Nodes to clock:</td>
              <td>
                <input
                  type="text"
                  name="clocknodes"
                  value={clockNodes}
                  onChange={(e) => setClockNodes(e.target.value)}
                  style={styles.input}
                />
              </td>
            </tr>
          </tbody>
        </table>
        <button type="submit" style={styles.submitButton}>
          Clock Speed
        </button>
      </form>

      {error && (
        <div style={styles.message}>
          <p>{error}</p>
        </div>
      )}

      {!hasResults && !error && (
        <p style={styles.message}>
          Okay, the radar gun's ready. Who should we clock?
        </p>
      )}

      {hasResults && (
        <div style={styles.results}>
          <p>
            {initialUsername} has <strong>{total_writeups}</strong> nodes in total.{' '}
            {total_writeups < initialClockNodes && (
              <>
                Since it's less than {initialClockNodes}, we'll just clock them for {actual_count}.
                <br />
              </>
            )}
            To write the last {actual_count} nodes, it took {initialUsername} {days_elapsed} days.
            This works out at <strong>{speed.toFixed(2)}</strong> days per node.
          </p>

          {/* Speedometer visualization */}
          <div style={styles.speedometerContainer}>
            <table style={styles.speedometerTable}>
              <tbody>
                <tr>
                  <td>
                    <table style={styles.innerTable}>
                      <tbody>
                        <tr>
                          <td style={styles.speedLabel}>
                            <small>
                              <strong>NODING SPEED</strong>
                            </small>
                          </td>
                        </tr>
                        <tr>
                          <td>
                            <table style={styles.barContainer}>
                              <tbody>
                                <tr>
                                  <td style={styles.barBackground}>
                                    <table style={{ ...styles.bar, width: `${width}%`, backgroundColor: color }}>
                                      <tbody>
                                        <tr>
                                          <td>
                                            <div style={styles.barContent} />
                                          </td>
                                        </tr>
                                      </tbody>
                                    </table>
                                  </td>
                                </tr>
                              </tbody>
                            </table>
                          </td>
                        </tr>
                      </tbody>
                    </table>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <p style={styles.comment}>{comment}</p>

          <hr style={styles.hr} />

          {/* Level-up projections */}
          {level_data && (
            <div style={styles.projections}>
              <p style={styles.projectionsHeading}>
                <big>
                  <strong>Level-up Projections</strong>
                </big>
              </p>
              <p>
                {initialUsername} needs <strong>{level_data.req_wu}</strong> nodes and{' '}
                <strong>{level_data.req_xp}</strong> experience to reach Level {level_data.next_level}.
                Based on a noding speed of <strong>{speed.toFixed(2)}</strong> days per node
                {level_data.req_xp > 0 && (
                  <>
                    , and an average XP per node of <strong>{level_data.avg_xp.toFixed(2)}</strong>{' '}
                    (clocked over the last {actual_count} nodes)
                  </>
                )}
                , this will take <strong>{Math.round(level_data.nodes_needed)}</strong> nodes,
                written over a period of <strong>{Math.round(level_data.days_to_level)}</strong> days.
              </p>
            </div>
          )}
        </div>
      )}
    </div>
  )
}

const styles = {
  container: {
    fontSize: '13px',
    lineHeight: '1.6',
    color: '#111'
  },
  form: {
    marginBottom: '20px'
  },
  label: {
    paddingRight: '10px',
    textAlign: 'right',
    verticalAlign: 'middle'
  },
  input: {
    padding: '4px 8px',
    border: '1px solid #dee2e6',
    borderRadius: '3px',
    fontSize: '13px',
    width: '200px'
  },
  submitButton: {
    marginTop: '10px',
    padding: '6px 12px',
    border: '1px solid #4060b0',
    borderRadius: '4px',
    backgroundColor: '#4060b0',
    color: '#fff',
    fontSize: '13px',
    cursor: 'pointer',
    fontWeight: '600'
  },
  message: {
    marginTop: '15px',
    fontSize: '13px'
  },
  results: {
    marginTop: '20px'
  },
  speedometerContainer: {
    textAlign: 'center',
    margin: '20px auto'
  },
  speedometerTable: {
    width: '300px',
    margin: 'auto',
    cellPadding: 0,
    cellSpacing: 0,
    borderCollapse: 'collapse'
  },
  innerTable: {
    width: '100%',
    border: 0,
    cellPadding: 0,
    cellSpacing: 0,
    borderCollapse: 'collapse'
  },
  speedLabel: {
    textAlign: 'left'
  },
  barContainer: {
    width: '260px',
    border: 'solid 1px black',
    cellPadding: 0,
    cellSpacing: 2,
    borderCollapse: 'separate',
    borderSpacing: '2px'
  },
  barBackground: {
    backgroundColor: 'gray',
    textAlign: 'left',
    padding: 0
  },
  bar: {
    border: 0,
    cellPadding: 0,
    cellSpacing: 0,
    borderCollapse: 'collapse'
  },
  barContent: {
    width: '1px',
    height: '13px'
  },
  comment: {
    textAlign: 'center',
    marginTop: '15px',
    fontSize: '13px'
  },
  hr: {
    width: '25%',
    marginTop: '20px',
    marginBottom: '20px'
  },
  projections: {
    marginTop: '20px'
  },
  projectionsHeading: {
    marginBottom: '10px'
  }
}

export default NodingSpeedometer
