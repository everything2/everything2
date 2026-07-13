import React, { useState, useEffect, useMemo } from 'react'

// Copy for the API error states (#4526): the server ships { state }, React owns the words.
const ERROR_COPY = {
  admin: 'This page is restricted to administrators.',
  param: 'Parameter error'
}

/**
 * HomenodeInspector - Inspect user homenodes for spam (admin).
 *
 * Fully client-resolved (#4526): the Page is a pure gate. This reads the filters off the URL and
 * fetches GET /api/homenode_inspector (which enforces the admin gate + runs the query). The filter
 * form + pagination navigate by query param (full page load, node preserved); read back on mount.
 */
const HomenodeInspector = () => {
  const nodeId = (typeof window !== 'undefined' && window.e2 && window.e2.node_id) || ''

  const initial = useMemo(() => {
    const qs = new URLSearchParams(window.location.search)
    return {
      gonetime: qs.get('gonetime') || '0',
      goneunit: (qs.get('goneunit') || 'month').toLowerCase(),
      showlength: qs.get('showlength') || '1000',
      maxwus: qs.get('maxwus') || '0',
      extlinks: qs.get('extlinks') ? '1' : '',
      dotstoo: qs.get('dotstoo') ? '1' : '',
      page: qs.get('page') || '1'
    }
  }, [])

  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const params = new URLSearchParams({
      gonetime: initial.gonetime, goneunit: initial.goneunit,
      showlength: initial.showlength, maxwus: initial.maxwus, page: initial.page
    })
    if (initial.extlinks) params.set('extlinks', '1')
    if (initial.dotstoo) params.set('dotstoo', '1')
    let cancelled = false
    fetch(`/api/homenode_inspector?${params}`, { credentials: 'same-origin' })
      .then((r) => r.json())
      .then((j) => { if (!cancelled) { setData(j); setLoading(false) } })
      .catch(() => { if (!cancelled) setLoading(false) })
    return () => { cancelled = true }
  }, [initial])

  if (loading) {
    return <div className="homenode-inspector"><p>Loading...</p></div>
  }
  if (data && data.success === 0) {
    return <div className="error-message">{ERROR_COPY[data.state] || 'Error'}</div>
  }

  const { filters = {}, pole_id, page = 1, items = [], total = 0, total_pages = 0 } = data || {}
  const {
    gonetime = 0, goneunit = 'MONTH', showlength = 1000, maxwus = 0, extlinks = 0, dotstoo = 0
  } = filters

  const pageLink = (p) =>
    `/?node_id=${nodeId}&gonetime=${gonetime}&goneunit=${goneunit}&showlength=${showlength}&maxwus=${maxwus}` +
    `${extlinks ? '&extlinks=1' : ''}${dotstoo ? '&dotstoo=1' : ''}&page=${p}`

  return (
    <div className="homenode-inspector">
      {/* Options form */}
      <form method="GET" action={`/?node_id=${nodeId}`}>
        <input type="hidden" name="node_id" value={nodeId} />

        <fieldset className="homenode-inspector__options">
          <legend>Options</legend>

          <label>
            Max writeups:{' '}
            <input type="text" name="maxwus" defaultValue={maxwus} size={2} />
          </label>
          <br />

          <label>
            Not logged in for:{' '}
            <input type="text" name="gonetime" defaultValue={gonetime} size={2} />
            <select name="goneunit" defaultValue={String(goneunit).toLowerCase()}>
              <option value="year">year</option>
              <option value="month">month</option>
              <option value="week">week</option>
              <option value="day">day</option>
            </select>
          </label>
          <br />

          <label>
            <input type="checkbox" name="extlinks" value="1" defaultChecked={Boolean(extlinks)} />
            {' '}Only homenodes with external links
          </label>
          <br />

          <label>
            <input type="checkbox" name="dotstoo" value="1" defaultChecked={Boolean(dotstoo)} />
            {' '}Include "..." homenodes
          </label>
          <br />

          <label>
            Only show{' '}
            <input type="text" name="showlength" defaultValue={showlength} size={3} />
            {' '}characters
          </label>
          <br /><br />

          <input type="submit" value="Go" />
        </fieldset>
      </form>

      {/* Results */}
      <p><strong>Found {total} matching homenodes</strong></p>

      {items.map((item) => (
        <div key={item.node_id} className="homenode-inspector__result-item">
          <p>
            <strong>
              <a href={`/?node_id=${item.node_id}`}>{item.title}</a>
            </strong>
            {' '}({item.full_length} chars)
          </p>

          <div className="homenode-inspector__doctext-preview">
            {item.doctext}
          </div>

          {pole_id && (
            <p className="homenode-inspector__smite-link">
              <a
                href={`/?node_id=${pole_id}&prefill=${encodeURIComponent(item.title)}`}
                className="action homenode-inspector__smite-action"
                title="Open The Old Hooked Pole with this username pre-filled"
              >
                Smite Spammer
              </a>
            </p>
          )}

          <hr />
        </div>
      ))}

      {/* Pagination */}
      {total_pages > 1 && (
        <div className="homenode-inspector__pagination">
          {page > 1 && (
            <a href={pageLink(page - 1)} className="homenode-inspector__prev-link">
              &laquo; Previous
            </a>
          )}

          <span>Page {page} of {total_pages}</span>

          {page < total_pages && (
            <a href={pageLink(page + 1)} className="homenode-inspector__next-link">
              Next &raquo;
            </a>
          )}
        </div>
      )}
    </div>
  )
}

export default HomenodeInspector
