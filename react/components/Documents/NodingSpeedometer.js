import React, { useState, useEffect, useCallback, useMemo } from 'react'

/**
 * Noding Speedometer - a user's noding speed (days per node) + level-up projection.
 * Styles in CSS: .noding-speedometer__*
 *
 * Fully client-resolved (#4539): the Page is a pure gate. Fetches GET /api/noding_speedometer
 * (NoGuest) on mount, reading speedyuser/clocknodes off the URL; the form refetches IN PLACE (no
 * reload) syncing the URL via history.pushState. The API ships the raw `speed`; the colour/width/
 * comment tiers are display config owned here.
 */

// speed is days-per-node -- lower is faster. First tier whose `max` is >= speed wins.
const SPEEDOMETER_TIERS = [
  { max: 0.75,     color: '#6600CC', width: 100, comment: (u) => `${u} has broken the speedometer and is probably not even human...` },
  { max: 1,        color: 'red',     width: 90,  comment: (u) => `IRON NODER speed! ${u} has been issued a ticket.` },
  { max: 3,        color: 'orange',  width: 75,  comment: () => 'Pretty fast! A warning and a doughnut bribe may be in order.' },
  { max: 7,        color: 'yellow',  width: 50,  comment: () => 'Nothing the node police need to worry about just yet.' },
  { max: 20,       color: 'green',   width: 25,  comment: () => 'We all get there in our own time, even if we cause tailbacks on the way...' },
  { max: Infinity, color: '#330000', width: 10,  comment: () => 'We politely suggest that you exit your vehicle and get a taxi. Perhaps the conversation will inspire you.' }
]
const speedometerFor = (speed, username) => {
  const tier = SPEEDOMETER_TIERS.find((t) => speed <= t.max)
  return { color: tier.color, width: tier.width, comment: tier.comment(username) }
}

const ERROR_COPY = {
  guest: () => 'Sorry, but only registered members can use the Noding Speedometer.',
  user_not_found: (u) => `Your aim is way off. ${u} isn't a user. Try again.`,
  no_writeups: (u) => `Um, user ${u} has no writeups!`,
  insufficient_days: () => 'Wait a while, do at least one lap around the track before timing yourself.'
}

const paramsFromUrl = () => {
  const qs = new URLSearchParams(window.location.search)
  return { speedyuser: qs.get('speedyuser') || '', clocknodes: qs.get('clocknodes') || '50' }
}

const NodingSpeedometer = () => {
  const initial = useMemo(paramsFromUrl, [])
  const [result, setResult] = useState(null)
  const [loading, setLoading] = useState(true)
  const [username, setUsername] = useState(initial.speedyuser)
  const [clockNodes, setClockNodes] = useState(initial.clocknodes)

  const load = useCallback((params, { push } = {}) => {
    const api = new URLSearchParams({ clocknodes: String(params.clocknodes || 50) })
    if (params.speedyuser) api.set('speedyuser', params.speedyuser)

    if (push) {
      const url = new URL(window.location.href)
      if (params.speedyuser) url.searchParams.set('speedyuser', params.speedyuser)
      else url.searchParams.delete('speedyuser')
      url.searchParams.set('clocknodes', String(params.clocknodes || 50))
      window.history.pushState({}, '', url.pathname + url.search)
    }

    setLoading(true)
    return fetch(`/api/noding_speedometer?${api}`, { credentials: 'same-origin' })
      .then((r) => r.json())
      .then((j) => { setResult(j); setLoading(false) })
      .catch(() => setLoading(false))
  }, [])

  useEffect(() => {
    load(initial)
    const onPop = () => {
      const q = paramsFromUrl()
      setUsername(q.speedyuser); setClockNodes(q.clocknodes)
      load(q)
    }
    window.addEventListener('popstate', onPop)
    return () => window.removeEventListener('popstate', onPop)
  }, [load, initial])

  const onSubmit = (e) => {
    e.preventDefault()
    load({ speedyuser: username, clocknodes: clockNodes }, { push: true })
  }

  const r = result || {}
  const { state, username: resultUser = '', clock_nodes = 50, total_writeups, actual_count, days_elapsed, speed, level_data } = r
  const errorText = state && ERROR_COPY[state] ? ERROR_COPY[state](resultUser) : null
  const hasResults = !loading && !state && speed !== undefined
  const gauge = hasResults ? speedometerFor(speed, resultUser) : null

  return (
    <div className="noding-speedometer">
      <form onSubmit={onSubmit} className="noding-speedometer__form">
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

      {loading && <p className="noding-speedometer__message">Loading...</p>}

      {errorText && (
        <div className="noding-speedometer__message"><p>{errorText}</p></div>
      )}

      {!loading && !state && !hasResults && (
        <p className="noding-speedometer__message">
          Okay, the radar gun&apos;s ready. Who should we clock?
        </p>
      )}

      {hasResults && (
        <div className="noding-speedometer__results">
          <p>
            {resultUser} has <strong>{total_writeups}</strong> nodes in total.{' '}
            {total_writeups < clock_nodes && (
              <>
                Since it&apos;s less than {clock_nodes}, we&apos;ll just clock them for {actual_count}.
                <br />
              </>
            )}
            To write the last {actual_count} nodes, it took {resultUser} {days_elapsed} days.
            This works out at <strong>{speed.toFixed(2)}</strong> days per node.
          </p>

          {/* Speedometer visualization (colour/width from the React tier config) */}
          <div className="noding-speedometer__speedometer-container">
            <table className="noding-speedometer__speedometer-table">
              <tbody>
                <tr>
                  <td>
                    <table className="noding-speedometer__inner-table">
                      <tbody>
                        <tr>
                          <td className="noding-speedometer__speed-label">
                            <small><strong>NODING SPEED</strong></small>
                          </td>
                        </tr>
                        <tr>
                          <td>
                            <table className="noding-speedometer__bar-container">
                              <tbody>
                                <tr>
                                  <td className="noding-speedometer__bar-background">
                                    <table className="noding-speedometer__bar" style={{ width: `${gauge.width}%`, backgroundColor: gauge.color }}>
                                      <tbody>
                                        <tr>
                                          <td><div className="noding-speedometer__bar-content" /></td>
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

          <p className="noding-speedometer__comment">{gauge.comment}</p>

          <hr className="noding-speedometer__hr" />

          {level_data && (
            <div className="noding-speedometer__projections">
              <p className="noding-speedometer__projections-heading">
                <big><strong>Level-up Projections</strong></big>
              </p>
              <p>
                {resultUser} needs <strong>{level_data.req_wu}</strong> nodes and{' '}
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
