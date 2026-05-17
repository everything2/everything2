import React, { useState } from 'react'
import LinkNode from '../LinkNode'

/**
 * WhoKilledWhat - Admin tool to view user kill history
 *
 * Shows which writeups a user has killed with links to Node Heaven.
 */
const WhoKilledWhat = ({ data }) => {
  const {
    error,
    target_user,
    total_kills = 0,
    kills = [],
    offset = 0,
    limit = 100,
    offset_options = [],
    limit_options = [],
    node_heaven_id,
    heavenuser = ''
  } = data

  const [formData, setFormData] = useState({
    heavenuser: heavenuser,
    offset: offset,
    limit: limit
  })

  if (error) {
    return <div className="error-message">{error}</div>
  }

  const handleChange = (e) => {
    setFormData({ ...formData, [e.target.name]: e.target.value })
  }

  const nodeId = window.e2?.node_id || ''

  return (
    <div className="who-killed-what">
      {/* Search Form */}
      <form method="GET" className="who-killed__form">
        <input type="hidden" name="node_id" value={nodeId} />

        <span>And what has </span>
        <input
          type="text"
          name="heavenuser"
          value={formData.heavenuser}
          onChange={handleChange}
          placeholder="username"
          size={20}
        />
        <span> been up to?</span>
        <br />

        <span>offset: </span>
        <select name="offset" value={formData.offset} onChange={handleChange}>
          {offset_options.map(opt => (
            <option key={opt} value={opt}>{opt}</option>
          ))}
        </select>

        <span> limit: </span>
        <select name="limit" value={formData.limit} onChange={handleChange}>
          {limit_options.map(opt => (
            <option key={opt} value={opt}>{opt}</option>
          ))}
        </select>

        <span> </span>
        <button type="submit" className="who-killed__btn">
          Search
        </button>
      </form>

      {/* Results */}
      <table className="who-killed__table">
        <thead>
          <tr>
            <th className="who-killed__th">Time</th>
            <th className="who-killed__th">Title</th>
            <th className="who-killed__th">Author User</th>
            <th className="who-killed__th who-killed__th--right">Rep</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td colSpan={4} className="who-killed__summary-row">
              Kill count for {target_user}: {total_kills.toLocaleString()}
            </td>
          </tr>
          {kills.map((kill, idx) => (
            <tr key={kill.node_id} className={idx % 2 === 0 ? 'who-killed__row--even' : 'who-killed__row--odd'}>
              <td className="who-killed__td">{kill.createtime}</td>
              <td className="who-killed__td">
                {node_heaven_id ? (
                  <a href={`?node_id=${node_heaven_id}&visit_id=${kill.node_id}`}>
                    {kill.title}
                  </a>
                ) : (
                  kill.title
                )}
              </td>
              <td className="who-killed__td">
                {kill.author_id > 0 ? (
                  <LinkNode node_id={kill.author_id} title={kill.author} type="user" />
                ) : (
                  kill.author
                )}
              </td>
              <td className="who-killed__td--right">{kill.reputation}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

export default WhoKilledWhat
