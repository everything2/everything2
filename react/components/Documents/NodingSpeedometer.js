import React, { useState } from 'react'

/**
 * Noding Speedometer - Calculate user noding speed
 * Styles in CSS: .noding-speedometer__*
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
    <div className="noding-speedometer">
      <form method="POST" className="noding-speedometer__form">
        <input type="hidden" name="node_id" value={e2?.node_id || ''} />
        <table>
          <tbody>
            <tr>
              <td className="noding-speedometer__label">Username:</td>
              <td>
                <input
                  type="text"
                  name="speedyuser"
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  className="noding-speedometer__input"
                />
              </td>
            </tr>
            <tr>
              <td className="noding-speedometer__label">Nodes to clock:</td>
              <td>
                <input
                  type="text"
                  name="clocknodes"
                  value={clockNodes}
                  onChange={(e) => setClockNodes(e.target.value)}
                  className="noding-speedometer__input"
                />
              </td>
            </tr>
          </tbody>
        </table>
        <button type="submit" className="noding-speedometer__submit-button">
          Clock Speed
        </button>
      </form>

      {error && (
        <div className="noding-speedometer__message">
          <p>{error}</p>
        </div>
      )}

      {!hasResults && !error && (
        <p className="noding-speedometer__message">
          Okay, the radar gun's ready. Who should we clock?
        </p>
      )}

      {hasResults && (
        <div className="noding-speedometer__results">
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
          <div className="noding-speedometer__speedometer-container">
            <table className="noding-speedometer__speedometer-table">
              <tbody>
                <tr>
                  <td>
                    <table className="noding-speedometer__inner-table">
                      <tbody>
                        <tr>
                          <td className="noding-speedometer__speed-label">
                            <small>
                              <strong>NODING SPEED</strong>
                            </small>
                          </td>
                        </tr>
                        <tr>
                          <td>
                            <table className="noding-speedometer__bar-container">
                              <tbody>
                                <tr>
                                  <td className="noding-speedometer__bar-background">
                                    <table className="noding-speedometer__bar" style={{ width: `${width}%`, backgroundColor: color }}>
                                      <tbody>
                                        <tr>
                                          <td>
                                            <div className="noding-speedometer__bar-content" />
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

          <p className="noding-speedometer__comment">{comment}</p>

          <hr className="noding-speedometer__hr" />

          {/* Level-up projections */}
          {level_data && (
            <div className="noding-speedometer__projections">
              <p className="noding-speedometer__projections-heading">
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

export default NodingSpeedometer
