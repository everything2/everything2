import React, { useState } from 'react'
import LinkNode from '../LinkNode'

/**
 * Ip2name - Look up users by IP address.
 * Styles in CSS: .ip2name__*
 * Admin/Editor tool that searches user settings for matching IP addresses.
 */
const Ip2name = ({ data }) => {
  const { access_denied, ipaddy: initialIp, results: initialResults } = data

  const [ipaddy, setIpaddy] = useState(initialIp || '')
  const [results, setResults] = useState(initialResults || [])
  const [searched, setSearched] = useState(Boolean(initialIp))

  if (access_denied) {
    return (
      <div className="ip2name">
        <div className="ip2name__error-box">
          <p>Access denied. Editors and admins only.</p>
        </div>
      </div>
    )
  }

  const handleSubmit = (e) => {
    e.preventDefault()
    // Submit to server via page reload with query param
    const params = new URLSearchParams()
    params.set('node_id', window.e2?.node_id || '')
    params.set('ipaddy', ipaddy)
    window.location.href = `?${params.toString()}`
  }

  return (
    <div className="ip2name">
      <p className="ip2name__warning">
        Please use me sparingly! I am expensive to run! Note: this probably won&apos;t work too well
        with people that have dynamic IP addresses.
      </p>

      {searched && (
        <div className="ip2name__results">
          {results.length > 0 ? (
            <>
              <p>
                <strong>Users found:</strong>
              </p>
              <ul className="ip2name__list">
                {results.map((user) => (
                  <li key={user.node_id}>
                    <LinkNode nodeId={user.node_id} title={user.title} />
                  </li>
                ))}
              </ul>
            </>
          ) : (
            <p>
              <em>nein!</em>
            </p>
          )}
        </div>
      )}

      <form onSubmit={handleSubmit} className="ip2name__form">
        <label>
          IP Address:{' '}
          <input
            type="text"
            value={ipaddy}
            onChange={(e) => setIpaddy(e.target.value)}
            className="ip2name__input"
            placeholder="e.g. 192.168.1.1"
          />
        </label>{' '}
        <button type="submit" className="ip2name__button">
          Search
        </button>
      </form>
    </div>
  )
}

export default Ip2name
