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
      <p className="ebu__news-link">
        <small>
          <a href="/title/News+for+noders.+Stuff+that+matters.">News for noders. Stuff that matters.</a>
        </small>
      </p>

      <form method="POST" action="" className="ebu__form">
        <input type="hidden" name="node" value="Everything's Best Users" />
        <input type="hidden" name="displaytype" value="" />
        <input type="hidden" name="sexisgood" value="1" />
        <div className="ebu__form-controls">
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
            change
          </button>
        </div>
      </form>

      <p className="ebu__intro">
        Shake these people's manipulatory appendages. They deserve it.
        <br />
        <em>A drum roll please....</em>
      </p>

      <div className="ebu__table-wrapper">
        <table className="ebu__table" border="0" cellPadding="8" cellSpacing="0">
          <thead>
            <tr>
              <th className="ebu__table th--center"></th>
              <th className="ebu__table th--left">User</th>
              <th className="ebu__table th--right">{getSortLabel()}</th>
              <th className="ebu__table th--right"># Writeups</th>
              <th className="ebu__table th--center">Rank</th>
              <th className="ebu__table th--center">Level</th>
            </tr>
          </thead>
          <tbody>
            {users.length === 0 ? (
              <tr>
                <td colSpan="6" className="ebu__empty">
                  <em>No users found</em>
                </td>
              </tr>
            ) : (
              users.map((user, index) => (
                <tr
                  key={user.node_id}
                  className={index % 2 === 0 ? 'ebu__row--even' : 'ebu__row--odd'}
                >
                  <td className="ebu__table td--center">
                    <small>{index + 1}</small>
                  </td>
                  <td>
                    <a href={`/user/${encodeURIComponent(user.title)}?lastnode_id=`}>
                      {user.title}
                    </a>
                  </td>
                  <td className="ebu__table td--right">
                    {sortColumn === 'addiction'
                      ? (user[sortColumn] || 0).toFixed(2)
                      : (user[sortColumn] || 0)
                    }
                  </td>
                  <td className="ebu__table td--right">
                    {user.writeup_count || 0}
                  </td>
                  <td className="ebu__table td--center">
                    {user.level_title || 'Initiate'}
                  </td>
                  <td className="ebu__table td--center">
                    {user.level_value || 0}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  )
}
