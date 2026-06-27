import React, { useState } from 'react'
import LinkNode from '../LinkNode'

/**
 * CacheDump - Display node cache contents for this httpd process
 *
 * Admin tool showing cached nodes, their types, permanent status,
 * and group membership information.
 * Styles are in CSS classes (cache-dump__*)
 */
const CacheDump = ({ data = {} }) => {
  const {
    process_id,
    cache_size = 0,
    max_size = 0,
    num_permanent = 0,
    nodes = [],
    type_stats = [],
    perf_stats = [],
    stash_cache = { stashes: [], totals: {} },
    memoize_cache = [],
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

  // Helper to get rate class
  const getRateClass = (rate) => {
    const rateNum = parseFloat(rate)
    if (rateNum < 50) return 'cache-dump__td--rate-low'
    if (rateNum > 90) return 'cache-dump__td--rate-high'
    return 'cache-dump__td--rate-normal'
  }

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

      <h3>Cache Performance (this process)</h3>
      <p className="cache-dump__help-text">
        Hit/miss statistics since process start. High eviction + low hit rate = cache churn.
      </p>
      {perf_stats.length === 0 ? (
        <p><em>No statistics collected yet.</em></p>
      ) : (
        <table className="cache-dump__perf-table">
          <thead>
            <tr>
              <th>Type</th>
              <th>Hits</th>
              <th>Misses</th>
              <th>Stale</th>
              <th>Evictions</th>
              <th>Hit Rate</th>
            </tr>
          </thead>
          <tbody>
            {perf_stats.map(stat => (
              <tr key={stat.type}>
                <td>{stat.type}</td>
                <td className="cache-dump__td--right">{stat.hits}</td>
                <td className="cache-dump__td--right">{stat.misses}</td>
                <td className="cache-dump__td--right">{stat.stale}</td>
                <td className={stat.evictions > 10 ? 'cache-dump__td--warning' : 'cache-dump__td--right'}>
                  {stat.evictions}
                </td>
                <td className={getRateClass(stat.hit_rate)}>
                  {stat.hit_rate}%
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      <h3>Datastash Memoize Cache (this process)</h3>
      <p className="cache-dump__help-text">
        cached_stash() per-worker TTL cache (#3981/#4385). High hit rate = the TTL window is
        working; high decodes vs hits = window too short for the request rate; high grace = the
        cron is regenerating late (delta==0 re-checks).
      </p>
      {(!stash_cache.stashes || stash_cache.stashes.length === 0) ? (
        <p><em>No datastash reads cached yet.</em></p>
      ) : (
        <>
          <table className="cache-dump__perf-table">
            <thead>
              <tr>
                <th>Stash</th>
                <th>Hits</th>
                <th>Decodes</th>
                <th>Grace</th>
                <th>Hit Rate</th>
                <th>Size</th>
                <th>Age (s)</th>
                <th>Next (s)</th>
              </tr>
            </thead>
            <tbody>
              {stash_cache.stashes.map(s => (
                <tr key={s.name}>
                  <td>{s.name}{!s.cached && ' (evicted)'}</td>
                  <td className="cache-dump__td--right">{s.hits}</td>
                  <td className="cache-dump__td--right">{s.decodes}</td>
                  <td className="cache-dump__td--right">{s.grace}</td>
                  <td className={getRateClass(s.hit_rate)}>{s.hit_rate}%</td>
                  <td className="cache-dump__td--right">{s.cached ? `${(s.bytes / 1024).toFixed(1)} KB` : '—'}</td>
                  <td className="cache-dump__td--right">{s.cached ? s.age : '—'}</td>
                  <td className="cache-dump__td--right">{s.cached ? s.next_check_in : '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
          {(stash_cache.totals && (stash_cache.totals.hits || stash_cache.totals.decodes)) ? (
            <p className="cache-dump__help-text">
              Overall: {stash_cache.totals.hits} hits / {stash_cache.totals.decodes} decodes / {stash_cache.totals.grace} grace
              {' '}(<strong>{stash_cache.totals.hit_rate}%</strong> hit rate)
            </p>
          ) : null}
        </>
      )}

      <h3>Derived Memoize Cache (this process)</h3>
      <p className="cache-dump__help-text">
        memoized_build() per-worker cache of derived non-personalized values (e.g. the guest
        front page's assembled contentData, #4391). hits = full assembly skipped; builds =
        rebuilt (cold start, or a source feed refreshed). High hit rate = page served from cache.
      </p>
      {(!memoize_cache || memoize_cache.length === 0) ? (
        <p><em>No memoized builds yet.</em></p>
      ) : (
        <table className="cache-dump__perf-table">
          <thead>
            <tr>
              <th>Key</th>
              <th>Hits</th>
              <th>Builds</th>
              <th>Hit Rate</th>
              <th>Cached</th>
              <th>Age (s)</th>
            </tr>
          </thead>
          <tbody>
            {memoize_cache.map(m => (
              <tr key={m.name}>
                <td>{m.name}</td>
                <td className="cache-dump__td--right">{m.hits}</td>
                <td className="cache-dump__td--right">{m.builds}</td>
                <td className={getRateClass(m.hit_rate)}>{m.hit_rate}%</td>
                <td className="cache-dump__td--right">{m.cached ? 'yes' : 'no'}</td>
                <td className="cache-dump__td--right">{m.cached ? m.age : '—'}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      <h3>Type Breakdown (currently cached)</h3>
      <table className="cache-dump__perf-table">
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
                  className={filterType === stat.type ? 'cache-dump__filter-link--active' : 'cache-dump__filter-link'}
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

      <div className="cache-dump__filter-bar">
        <label>
          <input
            type="checkbox"
            checked={showPermanentOnly}
            onChange={(e) => setShowPermanentOnly(e.target.checked)}
          />
          {' '}Show permanent only
        </label>
        {filterType && (
          <span className="cache-dump__filter-status">
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
            <span className="cache-dump__meta">
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
      <p className="cache-dump__help-text">
        Cached group membership data for fast permission checks (isApproved, isGod, isEditor, etc.)
      </p>

      {group_cache.length === 0 ? (
        <p><em>No group membership data cached.</em></p>
      ) : (
        <ul>
          {group_cache.map(group => (
            <li key={group.group_id} className="cache-dump__group-item">
              <a
                href="#"
                onClick={(e) => {
                  e.preventDefault()
                  setExpandedGroups(prev => ({
                    ...prev,
                    [group.group_id]: !prev[group.group_id]
                  }))
                }}
                className="cache-dump__expand-link"
              >
                {expandedGroups[group.group_id] ? '▼' : '▶'}
              </a>
              {' '}
              <LinkNode node_id={group.group_id} title={group.group_title} />
              {' '}
              <span className="cache-dump__meta">
                ({group.group_type}, {group.member_count} members cached)
              </span>

              {expandedGroups[group.group_id] && (
                <ul className="cache-dump__member-list">
                  {group.members.map(member => (
                    <li key={member.node_id}>
                      <LinkNode node_id={member.node_id} title={member.title} />
                      {' '}
                      <span className="cache-dump__meta--small">
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
