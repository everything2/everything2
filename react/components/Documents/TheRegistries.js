import React, { useState, useEffect, useCallback } from 'react'
import RegistryFooter from '../shared/RegistryFooter'

/**
 * TheRegistries - List all registries by most recent entry
 * Styles in CSS: .the-registries__*
 *
 * Fetch-driven (#4548): the Page is a pure gate; this fetches GET /api/the_registries. The
 * "include empty" toggle refetches in place and pushes the URL (no full-page reload, was a
 * window.location assignment). Login-required: the API returns state:'guest' for guests.
 */
const TheRegistries = () => {
  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)

  const load = useCallback((includeEmpty, { push } = {}) => {
    setLoading(true)
    const params = new URLSearchParams()
    if (includeEmpty) params.set('include_empty', '1')
    if (push) {
      const url = new URL(window.location.href)
      if (includeEmpty) url.searchParams.set('include_empty', '1')
      else url.searchParams.delete('include_empty')
      window.history.pushState({}, '', url.pathname + url.search)
    }
    fetch(`/api/the_registries?${params}`, { credentials: 'same-origin' })
      .then((r) => r.json())
      .then((j) => setData(j))
      .catch(() => {})
      .finally(() => setLoading(false))
  }, [])

  useEffect(() => {
    const readEmpty = () => Boolean(new URLSearchParams(window.location.search).get('include_empty'))
    load(readEmpty())
    const onPop = () => load(readEmpty())
    window.addEventListener('popstate', onPop)
    return () => window.removeEventListener('popstate', onPop)
  }, [load])

  if (loading && !data) {
    return <div className="the-registries"><p>Loading...</p></div>
  }

  const { state, registries = [], count, include_empty } = data || {}

  if (state === 'guest') {
    return (
      <div className="the-registries">
        <p className="the-registries__guest-message">
          ...first, you'd better log in.
        </p>
      </div>
    )
  }

  const showEmpty = Boolean(include_empty)

  return (
    <div className="the-registries">
      <p className="the-registries__intro">
        Registries are listed in order of most recent entry.
      </p>

      <div className="the-registries__toggle-container">
        <label className="the-registries__toggle-label">
          <input
            type="checkbox"
            checked={showEmpty}
            onChange={() => load(!showEmpty, { push: true })}
            className="the-registries__toggle-input"
          />
          <span className="the-registries__toggle-text">Include empty registries</span>
        </label>
      </div>

      {count === 0 ? (
        <div className="the-registries__empty-state">
          <p>No registries found.</p>
        </div>
      ) : (
        <ul className="the-registries__list">
          {registries.map((registry) => (
            <li key={registry.node_id} className="the-registries__list-item">
              <a href={`/?node_id=${registry.node_id}`} className="the-registries__link">
                {registry.title}
              </a>
              {registry.entry_count === 0 && (
                <span className="the-registries__empty-badge">(empty)</span>
              )}
            </li>
          ))}
        </ul>
      )}

      <RegistryFooter currentPage="the_registries" />
    </div>
  )
}

export default TheRegistries
