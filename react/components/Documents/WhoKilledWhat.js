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
      <form method="GET" style={{ marginBottom: '1.5em' }}>
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
        <button type="submit" style={{
          padding: '4px 10px',
          backgroundColor: '#38495e',
          color: '#fff',
          border: 'none',
          borderRadius: '3px',
          cursor: 'pointer'
        }}>
          Search
        </button>
      </form>

      {/* Results */}
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead>
          <tr>
            <th style={{ textAlign: 'left', borderBottom: '1px solid #ccc', padding: '4px' }}>Time</th>
            <th style={{ textAlign: 'left', borderBottom: '1px solid #ccc', padding: '4px' }}>Title</th>
            <th style={{ textAlign: 'left', borderBottom: '1px solid #ccc', padding: '4px' }}>Author User</th>
            <th style={{ textAlign: 'right', borderBottom: '1px solid #ccc', padding: '4px' }}>Rep</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td colSpan={4} style={{ padding: '8px 4px', fontWeight: 'bold' }}>
              Kill count for {target_user}: {total_kills.toLocaleString()}
            </td>
          </tr>
          {kills.map((kill, idx) => (
            <tr key={kill.node_id} style={{ backgroundColor: idx % 2 === 0 ? '#fff' : '#f8f9f9' }}>
              <td style={{ padding: '4px' }}>{kill.createtime}</td>
              <td style={{ padding: '4px' }}>
                {node_heaven_id ? (
                  <a href={`?node_id=${node_heaven_id}&visit_id=${kill.node_id}`}>
                    {kill.title}
                  </a>
                ) : (
                  kill.title
                )}
              </td>
              <td style={{ padding: '4px' }}>
                {kill.author_id > 0 ? (
                  <LinkNode node_id={kill.author_id} title={kill.author} type="user" />
                ) : (
                  kill.author
                )}
              </td>
              <td style={{ textAlign: 'right', padding: '4px' }}>{kill.reputation}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

export default WhoKilledWhat
