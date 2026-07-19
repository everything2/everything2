import React, { useState, useEffect } from 'react'

/**
 * Everything's Best Writeups - 50 most cooled writeups (editor only)
 * Styles in CSS: .best-writeups__*
 *
 * Fetch-driven (#4546): the Page is a pure gate; the editor gate now lives in
 * GET /api/everything_s_best_writeups (the real boundary). Non-editors get success:0/state:'permission'.
 */
export default function EverythingsBestWriteups() {
  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let cancelled = false
    fetch('/api/everything_s_best_writeups', { credentials: 'same-origin' })
      .then((r) => r.json())
      .then((j) => { if (!cancelled) { setData(j); setLoading(false) } })
      .catch(() => { if (!cancelled) setLoading(false) })
    return () => { cancelled = true }
  }, [])

  if (loading) {
    return <div className="best-writeups"><p>Loading...</p></div>
  }

  const { success = 0, writeups = [] } = data || {}

  if (!success) {
    return (
      <div className="best-writeups">
        <p className="best-writeups__empty">
          This page is visible only to staff members.
        </p>
      </div>
    )
  }

  return (
    <div className="best-writeups">
      <h3>Everything's 50 "Most Cooled" Writeups</h3>
      <p className="best-writeups__subtitle">
        (Visible only to staff members)
      </p>

      {writeups.length === 0 ? (
        <p className="best-writeups__empty">
          No cooled writeups found
        </p>
      ) : (
        <table className="best-writeups__table">
          <thead>
            <tr className="best-writeups__header-row">
              <th className="best-writeups__th best-writeups__th--writeup">
                Writeup
              </th>
              <th className="best-writeups__th best-writeups__th--author">
                Author
              </th>
            </tr>
          </thead>
          <tbody>
            {writeups.map((w) => (
              <tr key={w.writeup_id}>
                <td className="best-writeups__td">
                  <a href={`/title/${encodeURIComponent(w.writeup_title)}?node_id=${w.writeup_id}`}>
                    {w.writeup_title}
                  </a>
                  {' - '}
                  <a href={`/title/${encodeURIComponent(w.parent_title)}?node_id=${w.parent_id}`}>
                    full
                  </a>
                  {' '}
                  <strong>{w.cooled}C!</strong>
                </td>
                <td className="best-writeups__td">
                  by{' '}
                  <a href={`/user/${encodeURIComponent(w.author_title)}?lastnode_id=`}>
                    {w.author_title}
                  </a>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  )
}
