import React, { useState, useEffect, useMemo } from 'react'

/**
 * Everything's Best Users - leaderboard by XP / devotion / addiction.
 *
 * Fully client-resolved (#4526): the Page is a pure gate. This reads the toggle filters off the URL
 * and fetches GET /api/everything_s_best_users (which runs the ranking). The toggle form navigates by
 * query param (full page load, bookmarkable); read back on mount. (Was a POST form before.)
 */
export default function EverythingsBestUsers() {
  const nodeId = (typeof window !== 'undefined' && window.e2 && window.e2.node_id) || ''

  const initial = useMemo(() => {
    const qs = new URLSearchParams(window.location.search)
    return {
      showDevotion: qs.get('ebu_showdevotion') ? '1' : '',
      showAddiction: qs.get('ebu_showaddiction') ? '1' : '',
      showNewUsers: qs.get('ebu_newusers') ? '1' : '',
      showRecent: qs.get('ebu_showrecent') ? '1' : ''
    }
  }, [])

  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const params = new URLSearchParams()
    if (initial.showDevotion) params.set('ebu_showdevotion', '1')
    if (initial.showAddiction) params.set('ebu_showaddiction', '1')
    if (initial.showNewUsers) params.set('ebu_newusers', '1')
    if (initial.showRecent) params.set('ebu_showrecent', '1')
    let cancelled = false
    fetch(`/api/everything_s_best_users?${params}`, { credentials: 'same-origin' })
      .then((r) => r.json())
      .then((j) => { if (!cancelled) { setData(j); setLoading(false) } })
      .catch(() => { if (!cancelled) setLoading(false) })
    return () => { cancelled = true }
  }, [initial])

  const {
    users = [], showDevotion = false, showAddiction = false, showNewUsers = false, showRecent = false
  } = data || {}

  const getSortColumn = () => (showDevotion ? 'devotion' : showAddiction ? 'addiction' : 'experience')
  const getSortLabel = () => (showDevotion ? 'Devotion' : showAddiction ? 'Addiction' : 'Experience')
  const sortColumn = getSortColumn()

  if (loading) {
    return <div className="ebu"><p>Loading...</p></div>
  }

  return (
    <div className="ebu">
      <div className="ebu__header">
        <p className="ebu__subtitle">
          Shake these people's manipulatory appendages. They deserve it.
        </p>
      </div>

      <form method="GET" action={`/?node_id=${nodeId}`} className="ebu__form">
        <input type="hidden" name="node_id" value={nodeId} />
        <div className="ebu__form-row">
          <label className="ebu__checkbox-label">
            <input type="checkbox" name="ebu_showdevotion" value="1" defaultChecked={Boolean(showDevotion)} />
            Display by <a href="/title/devotion">devotion</a>
          </label>

          <label className="ebu__checkbox-label">
            <input type="checkbox" name="ebu_showaddiction" value="1" defaultChecked={Boolean(showAddiction)} />
            Display by <a href="/title/addiction">addiction</a>
          </label>

          <label className="ebu__checkbox-label">
            <input type="checkbox" name="ebu_newusers" value="1" defaultChecked={Boolean(showNewUsers)} />
            Show New users
          </label>

          <label className="ebu__checkbox-label">
            <input type="checkbox" name="ebu_showrecent" value="1" defaultChecked={Boolean(showRecent)} />
            Don't show fled users
          </label>

          <button type="submit" className="ebu__submit-btn">
            Update
          </button>
        </div>
      </form>

      <div className="ebu__results">
        <div className="ebu__results-header">
          <span className="ebu__results-count">
            {users.length} user{users.length !== 1 ? 's' : ''} ranked by {getSortLabel().toLowerCase()}
          </span>
          <a href="/title/News+for+noders.+Stuff+that+matters." className="ebu__news-link">
            News for noders
          </a>
        </div>

        <div className="ebu__table-container">
          <table className="ebu__table">
            <colgroup>
              <col />
              <col />
              <col />
              <col />
              <col className="ebu__hide-mobile" />
              <col className="ebu__hide-mobile" />
            </colgroup>
            <thead>
              <tr>
                <th className="ebu__th ebu__th--center">#</th>
                <th className="ebu__th ebu__th--left">User</th>
                <th className="ebu__th ebu__th--right">{getSortLabel()}</th>
                <th className="ebu__th ebu__th--right">Writeups</th>
                <th className="ebu__th ebu__th--center ebu__hide-mobile">Rank</th>
                <th className="ebu__th ebu__th--center ebu__hide-mobile">Level</th>
              </tr>
            </thead>
            <tbody>
              {users.length === 0 ? (
                <tr>
                  <td colSpan="6" className="ebu__empty">
                    No users found matching the criteria.
                  </td>
                </tr>
              ) : (
                users.map((user, index) => (
                  <tr
                    key={user.node_id}
                    className={index % 2 === 0 ? 'ebu__row--even' : 'ebu__row--odd'}
                  >
                    <td className="ebu__td ebu__td--center ebu__td--rank">
                      {index + 1}
                    </td>
                    <td className="ebu__td">
                      <a href={`/user/${encodeURIComponent(user.title)}?lastnode_id=`} className="ebu__user-link">
                        {user.title}
                      </a>
                    </td>
                    <td className="ebu__td ebu__td--right">
                      <span className="ebu__value">
                        {sortColumn === 'addiction'
                          ? (user[sortColumn] || 0).toFixed(2)
                          : (user[sortColumn] || 0).toLocaleString()
                        }
                      </span>
                    </td>
                    <td className="ebu__td ebu__td--right">
                      <span className="ebu__value">
                        {(user.writeup_count || 0).toLocaleString()}
                      </span>
                    </td>
                    <td className="ebu__td ebu__td--center ebu__hide-mobile">
                      <span className="ebu__rank">{user.level_title || 'Initiate'}</span>
                    </td>
                    <td className="ebu__td ebu__td--center ebu__hide-mobile">
                      <span className="ebu__level">{user.level_value || 0}</span>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}
