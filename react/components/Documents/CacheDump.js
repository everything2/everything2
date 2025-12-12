import React, { useState } from 'react'
import LinkNode from '../LinkNode'

/**
 * CacheDump - Display node cache contents for this httpd process
 *
 * Admin tool showing cached nodes, their types, permanent status,
 * and group membership information.
 */
const CacheDump = ({ data = {} }) => {
  const {
    process_id,
    cache_size = 0,
    max_size = 0,
    num_permanent = 0,
    nodes = [],
    type_stats = [],
    group_cache = [],
    group_cache_size = 0,
    error
  } = data

  const [filterType, setFilterType] = useState('')
  const [showPermanentOnly, setShowPermanentOnly] = useState(false)
  const [expandedGroups, setExpandedGroups] = useState({})

  if (error) {
    return <div className="error-message">{error}</div>
  }

  // Filter nodes based on user selections
  const filteredNodes = nodes.filter(node => {
    if (filterType && node.type !== filterType) return false
    if (showPermanentOnly && !node.permanent) return false
    return true
  })

  const utilizationPercent = max_size > 0
    ? Math.round((cache_size / max_size) * 100)
    : 0

  return (
    <div className="cache-dump">
      <h3>Cache Statistics</h3>
      <p>
        <strong>Process ID:</strong> {process_id}
      </p>
      <p>
        <strong>Cache Size:</strong> {cache_size} / {max_size} nodes ({utilizationPercent}% utilized)
      </p>
      <p>
        <strong>Permanent Nodes:</strong> {num_permanent}
      </p>

      <h3>Type Breakdown</h3>
      <table style={{ marginBottom: '1em' }}>
        <thead>
          <tr>
            <th>Type</th>
            <th>Count</th>
          </tr>
        </thead>
        <tbody>
          {type_stats.map(stat => (
            <tr key={stat.type}>
              <td>
                <a
                  href="#"
                  onClick={(e) => {
                    e.preventDefault()
                    setFilterType(filterType === stat.type ? '' : stat.type)
                  }}
                  style={{
                    fontWeight: filterType === stat.type ? 'bold' : 'normal'
                  }}
                >
                  {stat.type}
                </a>
              </td>
              <td>{stat.count}</td>
            </tr>
          ))}
        </tbody>
      </table>

      <h3>Cached Nodes ({filteredNodes.length})</h3>

      <div style={{ marginBottom: '1em' }}>
        <label>
          <input
            type="checkbox"
            checked={showPermanentOnly}
            onChange={(e) => setShowPermanentOnly(e.target.checked)}
          />
          {' '}Show permanent only
        </label>
        {filterType && (
          <span style={{ marginLeft: '1em' }}>
            Filtering by: <strong>{filterType}</strong>
            {' '}
            <a href="#" onClick={(e) => { e.preventDefault(); setFilterType('') }}>
              (clear)
            </a>
          </span>
        )}
      </div>

      <ul>
        {filteredNodes.map(node => (
          <li key={node.node_id}>
            <LinkNode node_id={node.node_id} title={node.title} />
            {' '}
            <span style={{ color: '#666' }}>
              ({node.type}
              {Boolean(node.permanent) && ', permanent'}
              {node.group_size !== undefined && `, ${node.group_size} in group`}
              {node.group_cache_size !== undefined && `, ${node.group_cache_size} in groupCache`}
              )
            </span>
          </li>
        ))}
      </ul>

      {filteredNodes.length === 0 && (
        <p><em>No nodes match the current filter.</em></p>
      )}

      <h3>Group Cache ({group_cache_size} groups)</h3>
      <p style={{ fontSize: '0.9em', color: '#666' }}>
        Cached group membership data for fast permission checks (isApproved, isGod, isEditor, etc.)
      </p>

      {group_cache.length === 0 ? (
        <p><em>No group membership data cached.</em></p>
      ) : (
        <ul>
          {group_cache.map(group => (
            <li key={group.group_id} style={{ marginBottom: '0.5em' }}>
              <a
                href="#"
                onClick={(e) => {
                  e.preventDefault()
                  setExpandedGroups(prev => ({
                    ...prev,
                    [group.group_id]: !prev[group.group_id]
                  }))
                }}
                style={{ fontWeight: 'bold' }}
              >
                {expandedGroups[group.group_id] ? '▼' : '▶'}
              </a>
              {' '}
              <LinkNode node_id={group.group_id} title={group.group_title} />
              {' '}
              <span style={{ color: '#666' }}>
                ({group.group_type}, {group.member_count} members cached)
              </span>

              {expandedGroups[group.group_id] && (
                <ul style={{ marginTop: '0.5em' }}>
                  {group.members.map(member => (
                    <li key={member.node_id}>
                      <LinkNode node_id={member.node_id} title={member.title} />
                      {' '}
                      <span style={{ color: '#999', fontSize: '0.9em' }}>
                        ({member.type})
                      </span>
                    </li>
                  ))}
                </ul>
              )}
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}

export default CacheDump
