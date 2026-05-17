import React from 'react'

export default function EverythingsBestUsers({ data }) {
  const {
    users = [],
    showDevotion = false,
    showAddiction = false,
    showNewUsers = false,
    showRecent = false
  } = data

  const getSortColumn = () => {
    if (showDevotion) return 'devotion'
    if (showAddiction) return 'addiction'
    return 'experience'
  }

  const getSortLabel = () => {
    if (showDevotion) return 'Devotion'
    if (showAddiction) return 'Addiction'
    return 'Experience'
  }

  const sortColumn = getSortColumn()

  return (
    <div className="ebu">
      <div className="ebu__header">
        <p className="ebu__subtitle">
          Shake these people's manipulatory appendages. They deserve it.
        </p>
      </div>

      <form method="POST" action="" className="ebu__form">
        <input type="hidden" name="node" value="Everything's Best Users" />
        <input type="hidden" name="displaytype" value="" />
        <input type="hidden" name="sexisgood" value="1" />
        <div className="ebu__form-row">
          <label className="ebu__checkbox-label">
            <input
              type="checkbox"
              name="ebu_showdevotion"
              defaultChecked={showDevotion}
            />
            Display by <a href="/title/devotion">devotion</a>
          </label>

          <label className="ebu__checkbox-label">
            <input
              type="checkbox"
              name="ebu_showaddiction"
              defaultChecked={showAddiction}
            />
            Display by <a href="/title/addiction">addiction</a>
          </label>

          <label className="ebu__checkbox-label">
            <input
              type="checkbox"
              name="ebu_newusers"
              defaultChecked={showNewUsers}
            />
            Show New users
          </label>

          <label className="ebu__checkbox-label">
            <input
              type="checkbox"
              name="ebu_showrecent"
              defaultChecked={showRecent}
            />
            Don't show fled users
          </label>

          <input type="hidden" name="gochange" value="foo" />
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
