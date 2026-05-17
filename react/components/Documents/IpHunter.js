import React, { useState } from 'react'
import LinkNode from '../LinkNode'

/**
 * IP Hunter - Admin tool for tracking IP addresses and user logins
 * Styles in CSS: .ip-hunter__*
 *
 * Allows admins to search by:
 * - Username: See all IPs a user has logged in from
 * - IP Address: See all users that have logged in from an IP
 */
const IpHunter = ({ data, e2 }) => {
  const {
    error,
    search_type,
    search_value,
    user_id,
    user_title,
    results = [],
    result_limit
  } = data

  const [huntName, setHuntName] = useState('')
  const [huntIp, setHuntIp] = useState('')

  // IP lookup tools helper
  const renderIpLookup = (ip) => {
    return (
      <span className="ip-hunter__lookup-links">
        <a href={`http://whois.arin.net/rest/ip/${ip}`} target="_blank" rel="noopener noreferrer">ARIN</a>
        {' | '}
        <a href={`https://www.robtex.com/ip-lookup/${ip}`} target="_blank" rel="noopener noreferrer">Robtex</a>
        {' | '}
        <a href={`https://www.shodan.io/host/${ip}`} target="_blank" rel="noopener noreferrer">Shodan</a>
      </span>
    )
  }

  if (error) {
    return (
      <div className="ip-hunter">
        <div className="ip-hunter__error-box">{error}</div>
      </div>
    )
  }

  return (
    <div className="ip-hunter">
      {/* Search Form */}
      <form method="post" className="ip-hunter__form">
        <input type="hidden" name="node_id" value={e2?.node_id || ''} />
        <table className="ip-hunter__form-table">
          <tbody>
            <tr>
              <td className="ip-hunter__label-cell"><strong>name:</strong></td>
              <td>
                <input
                  type="text"
                  name="hunt_name"
                  value={huntName}
                  onChange={(e) => setHuntName(e.target.value)}
                  className="ip-hunter__input"
                />
              </td>
            </tr>
            <tr>
              <td></td>
              <td><strong> - or -</strong></td>
            </tr>
            <tr>
              <td className="ip-hunter__label-cell"><strong>IP:</strong></td>
              <td>
                <input
                  type="text"
                  name="hunt_ip"
                  value={huntIp}
                  onChange={(e) => setHuntIp(e.target.value)}
                  className="ip-hunter__input"
                />
              </td>
            </tr>
            <tr>
              <td></td>
              <td>
                <input type="submit" value="hunt" className="ip-hunter__submit-button" />
              </td>
            </tr>
          </tbody>
        </table>
      </form>

      <hr className="ip-hunter__divider" />

      {/* Results */}
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
                    <a href={`?hunt_name=${encodeURIComponent(result.user_title)}`}>hunt</a>
                  </td>
                  <td className="ip-hunter__td">{result.time}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

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
                return (
                  <tr key={idx}>
                    <td className="ip-hunter__td">{idx + 1}</td>
                    <td className="ip-hunter__td">
                      {isBanned ? (
                        <strike><strong>
                          <a href={`?hunt_ip=${encodeURIComponent(result.ip)}`}>{result.ip}</a>
                        </strong></strike>
                      ) : (
                        <a href={`?hunt_ip=${encodeURIComponent(result.ip)}`}>{result.ip}</a>
                      )}
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

      {!search_type && !error && (
        <p>Please enter an IP address or a name to continue</p>
      )}
    </div>
  )
}

export default IpHunter
