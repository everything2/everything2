import React, { useState, useEffect, useMemo } from 'react'

const ERROR_COPY = {
  admin: 'This page is restricted to administrators.'
}

/**
 * CajaDeArena - Sandbox spam detection tool (admin).
 *
 * Fully client-resolved (#4526): the Page is a pure gate. This reads the filters off the URL and
 * fetches GET /api/caja_de_arena (admin-gated + runs the query). The filter form + pagination
 * navigate by query param (full page load, node preserved); read back on mount.
 */
const CajaDeArena = () => {
  const nodeId = (typeof window !== 'undefined' && window.e2 && window.e2.node_id) || ''

  const initial = useMemo(() => {
    const qs = new URLSearchParams(window.location.search)
    return {
      gonesince: qs.get('gonesince') || '1 YEAR',
      showlength: qs.get('showlength') || '1000',
      published: qs.get('published') ? '1' : '',
      extlinks: qs.get('extlinks') ? '1' : '',
      page: qs.get('page') || '1'
    }
  }, [])

  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const params = new URLSearchParams({
      gonesince: initial.gonesince, showlength: initial.showlength, page: initial.page
    })
    if (initial.published) params.set('published', '1')
    if (initial.extlinks) params.set('extlinks', '1')
    let cancelled = false
    fetch(`/api/caja_de_arena?${params}`, { credentials: 'same-origin' })
      .then((r) => r.json())
      .then((j) => { if (!cancelled) { setData(j); setLoading(false) } })
      .catch(() => { if (!cancelled) setLoading(false) })
    return () => { cancelled = true }
  }, [initial])

  // Split the current gonesince into number + unit for the form controls.
  const [rawNum, rawUnit] = (initial.gonesince || '1 YEAR').split(/\s+/)
  const [goneNum, setGoneNum] = useState(rawNum || '1')
  const [goneUnit, setGoneUnit] = useState((rawUnit || 'YEAR').toUpperCase())

  if (loading) {
    return <div className="caja-de-arena"><p>Loading...</p></div>
  }
  if (data && data.success === 0) {
    return <div className="error-message">{ERROR_COPY[data.state] || 'Error'}</div>
  }

  const { filters = {}, pole_id, page = 1, items = [], total = 0, total_pages = 0 } = data || {}
  const { gonesince = '1 YEAR', showlength = 1000, published = 0, extlinks = 0 } = filters

  const pageLink = (p) =>
    `/?node_id=${nodeId}&gonesince=${encodeURIComponent(gonesince)}&showlength=${showlength}` +
    `${published ? '&published=1' : ''}${extlinks ? '&extlinks=1' : ''}&page=${p}`

  return (
    <div className="caja-de-arena">
      {/* Options form. gonenum + goneunit are combined into the gonesince param the API reads
          (the old form submitted an always-empty hidden gonesince, so the unit picker did nothing). */}
      <form method="GET" action={`/?node_id=${nodeId}`}>
        <input type="hidden" name="node_id" value={nodeId} />
        <input type="hidden" name="gonesince" value={`${goneNum} ${goneUnit}`} />

        <fieldset className="caja__fieldset">
          <legend>Sandbox Options</legend>

          <label>
            Not logged in for:{' '}
            <input type="text" value={goneNum} onChange={(e) => setGoneNum(e.target.value)} size={2} />
            <select value={goneUnit} onChange={(e) => setGoneUnit(e.target.value)}>
              <option value="YEAR">YEAR</option>
              <option value="MONTH">MONTH</option>
              <option value="WEEK">WEEK</option>
              <option value="DAY">DAY</option>
            </select>
          </label>
          <br />

          <label>
            <input type="checkbox" name="published" value="1" defaultChecked={Boolean(published)} />
            {' '}Include users with writeups (default: only zero-writeup users)
          </label>
          <br />

          <label>
            <input type="checkbox" name="extlinks" value="1" defaultChecked={Boolean(extlinks)} />
            {' '}Only homenodes with external links
          </label>
          <br />

          <label>
            Only show{' '}
            <input type="text" name="showlength" defaultValue={showlength} size={3} />
            {' '}characters
          </label>
          <br /><br />

          <input type="submit" value="Search" />
        </fieldset>
      </form>

      {/* Results header */}
      <p><strong>Spam entries: {total} found</strong></p>

      {items.map((item) => (
        <div key={item.node_id} className="caja__result-card">
          <p>
            <strong>
              <a href={`/?node_id=${item.node_id}`}>{item.title}</a>
            </strong>
            {' '}({item.full_length} chars)
          </p>

          <div className="caja__doctext-preview">
            {item.doctext}
          </div>

          {pole_id && (
            <p className="caja__smite-wrapper">
              <hr />
              <a
                href={`/?node_id=${pole_id}&prefill=${encodeURIComponent(item.title)}`}
                className="action caja__smite-link"
                title="Open The Old Hooked Pole with this username pre-filled"
              >
                Smite Spammer
              </a>
            </p>
          )}
        </div>
      ))}

      {items.length === 0 && (
        <p className="caja__empty-message">
          No matching homenodes found with current filters.
        </p>
      )}

      {/* Pagination */}
      {total_pages > 1 && (
        <div className="caja__pagination">
          {page > 1 && (
            <a href={pageLink(page - 1)} className="caja__pagination-prev">
              &laquo; Previous
            </a>
          )}

          <span>Page {page} of {total_pages}</span>

          {page < total_pages && (
            <a href={pageLink(page + 1)} className="caja__pagination-next">
              Next &raquo;
            </a>
          )}
        </div>
      )}
    </div>
  )
}

export default CajaDeArena
