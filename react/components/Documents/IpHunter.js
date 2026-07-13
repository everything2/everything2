import React, { useState, useEffect, useCallback } from 'react'
import LinkNode from '../LinkNode'

/**
 * IP Hunter - Admin tool for tracking IP addresses and user logins
 * Styles in CSS: .ip-hunter__*
 *
 * Fully client-resolved (#4530): the Page is a pure gate. This fetches GET /api/ip_hunter
 * (admin-gated) on mount, reading hunt_name/hunt_ip off the URL. The search form and the "hunt"
 * cross-links refetch IN PLACE -- no full page reload -- syncing the URL via history.pushState
 * (popstate refetches). Error copy (admin / user_not_found) is owned here, keyed on the state flag.
 */
const ERROR_COPY = {
  admin: 'Access denied. This tool is restricted to administrators.',
  user_not_found: (v) => `No such user: ${v}`
}

const paramsFromUrl = () => {
  const qs = new URLSearchParams(window.location.search)
  return { hunt_name: qs.get('hunt_name') || '', hunt_ip: qs.get('hunt_ip') || '' }
}

const IpHunter = () => {
  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)
  const init = paramsFromUrl()
  const [huntName, setHuntName] = useState(init.hunt_name)
  const [huntIp, setHuntIp] = useState(init.hunt_ip)

  const load = useCallback((params, { push } = {}) => {
    const api = new URLSearchParams()
    if (params.hunt_ip) api.set('hunt_ip', params.hunt_ip)
    else if (params.hunt_name) api.set('hunt_name', params.hunt_name)

    if (push) {
      const url = new URL(window.location.href)
      url.searchParams.delete('hunt_name')
      url.searchParams.delete('hunt_ip')
      if (params.hunt_ip) url.searchParams.set('hunt_ip', params.hunt_ip)
      else if (params.hunt_name) url.searchParams.set('hunt_name', params.hunt_name)
      window.history.pushState({}, '', url.pathname + url.search)
    }

    setLoading(true)
    return fetch(`/api/ip_hunter?${api}`, { credentials: 'same-origin' })
      .then((r) => r.json())
      .then((j) => { setData(j); setLoading(false) })
      .catch(() => setLoading(false))
  }, [])

  useEffect(() => {
    load(paramsFromUrl())
    const onPop = () => {
      const p = paramsFromUrl()
      setHuntName(p.hunt_name); setHuntIp(p.hunt_ip)
      load(p)
    }
    window.addEventListener('popstate', onPop)
    return () => window.removeEventListener('popstate', onPop)
  }, [load])

  // IP reputation lookup links (external).
  const renderIpLookup = (ip) => (
    <span className="ip-hunter__lookup-links">
      <a href={`http://whois.arin.net/rest/ip/${ip}`} target="_blank" rel="noopener noreferrer">ARIN</a>
      {' | '}
      <a href={`https://www.robtex.com/ip-lookup/${ip}`} target="_blank" rel="noopener noreferrer">Robtex</a>
      {' | '}
      <a href={`https://www.shodan.io/host/${ip}`} target="_blank" rel="noopener noreferrer">Shodan</a>
    </span>
  )

  if (loading && !data) {
    return <div className="ip-hunter"><p>Loading...</p></div>
  }
  if (data && data.state === 'admin') {
    return <div className="ip-hunter"><div className="ip-hunter__error-box">{ERROR_COPY.admin}</div></div>
  }

  const { state, search_type, search_value, user_id, user_title, results = [], result_limit } = data || {}
  const errorText = state === 'user_not_found' ? ERROR_COPY.user_not_found(search_value) : null

  const onSubmit = (e) => {
    e.preventDefault()
    load({ hunt_name: huntName, hunt_ip: huntIp }, { push: true })
  }
  // "hunt" cross-links refetch in place (an IP row -> hunt that IP; a user row -> hunt that user).
  const huntIpLink = (ip) => (e) => { e.preventDefault(); setHuntIp(ip); setHuntName(''); load({ hunt_ip: ip }, { push: true }) }
  const huntNameLink = (name) => (e) => { e.preventDefault(); setHuntName(name); setHuntIp(''); load({ hunt_name: name }, { push: true }) }

  return (
    <div className="ip-hunter">
      {/* Search form -- submits in place */}
      <form className="ip-hunter__form" onSubmit={onSubmit}>
        <table className="ip-hunter__form-table">
          <tbody>
            <tr>
              <td className="ip-hunter__label-cell"><strong>name:</strong></td>
              <td>
                <input type="text" name="hunt_name" value={huntName}
                  onChange={(e) => setHuntName(e.target.value)} className="ip-hunter__input" />
              </td>
            </tr>
            <tr><td></td><td><strong> - or -</strong></td></tr>
            <tr>
              <td className="ip-hunter__label-cell"><strong>IP:</strong></td>
              <td>
                <input type="text" name="hunt_ip" value={huntIp}
                  onChange={(e) => setHuntIp(e.target.value)} className="ip-hunter__input" />
              </td>
            </tr>
            <tr>
              <td></td>
              <td><input type="submit" value="hunt" className="ip-hunter__submit-button" /></td>
            </tr>
          </tbody>
        </table>
      </form>

      <hr className="ip-hunter__divider" />

      {errorText && <div className="ip-hunter__error-box">{errorText}</div>}

      {/* Results: by IP -> users */}
      {search_type === 'ip' && (
        <div>
          <p>
            The IP ({search_value}) <small>({renderIpLookup(search_value)})</small> has been here and logged on as:
          </p>
          <p className="ip-hunter__limit-note">(only showing {result_limit} most recent)</p>
          <table className="ip-hunter__results-table">
            <thead>
              <tr>
                <th className="ip-hunter__th">#</th>
                <th className="ip-hunter__th" colSpan="2">Who (Hunt User)</th>
                <th className="ip-hunter__th">When</th>
              </tr>
            </thead>
            <tbody>
              {results.map((result, idx) => (
                <tr key={idx}>
                  <td className="ip-hunter__td">{idx + 1}</td>
                  <td className="ip-hunter__td">
                    {result.user_id ? (
                      <LinkNode nodeId={result.user_id} title={result.user_title} />
                    ) : (
                      <strong>Deleted user</strong>
                    )}
                  </td>
                  <td className="ip-hunter__td ip-hunter__td--right">
                    <a href={`?hunt_name=${encodeURIComponent(result.user_title)}`} onClick={huntNameLink(result.user_title)}>hunt</a>
                  </td>
                  <td className="ip-hunter__td">{result.time}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Results: by user -> IPs */}
      {search_type === 'user' && (
        <div>
          <p>
            The user {user_id ? <LinkNode nodeId={user_id} title={user_title} /> : user_title} has been here as IPs:
          </p>
          <p className="ip-hunter__limit-note">(only showing {result_limit} most recent)</p>
          <table className="ip-hunter__results-table">
            <thead>
              <tr>
                <th className="ip-hunter__th">#</th>
                <th className="ip-hunter__th">IP</th>
                <th className="ip-hunter__th">When</th>
                <th className="ip-hunter__th">Look up</th>
              </tr>
            </thead>
            <tbody>
              {results.map((result, idx) => {
                const isBanned = result.banned || result.banned_ranged
                const ipLink = <a href={`?hunt_ip=${encodeURIComponent(result.ip)}`} onClick={huntIpLink(result.ip)}>{result.ip}</a>
                return (
                  <tr key={idx}>
                    <td className="ip-hunter__td">{idx + 1}</td>
                    <td className="ip-hunter__td">
                      {isBanned ? <strike><strong>{ipLink}</strong></strike> : ipLink}
                    </td>
                    <td className="ip-hunter__td">{result.time}</td>
                    <td className="ip-hunter__td">{renderIpLookup(result.ip)}</td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
      )}

      {!search_type && !errorText && (
        <p>Please enter an IP address or a name to continue</p>
      )}
    </div>
  )
}

export default IpHunter
