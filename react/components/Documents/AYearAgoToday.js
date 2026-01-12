import React from 'react'
import LinkNode from '../LinkNode'

/**
 * A Year Ago Today - Shows writeups from previous years on this date
 *
 * Supports pagination and year selection
 */
const AYearAgoToday = ({ data }) => {
  const { nodes = [], current_year, count, yearsago, startat, node } = data

  // Calculate pagination
  const perPage = 50
  const currentPage = Math.floor(startat / perPage)
  const hasPrev = startat >= perPage
  const hasNext = startat + perPage < count

  // Generate year links
  const years = []
  for (let year = 1999; year < current_year; year++) {
    const yearsAgo = current_year - year
    years.push({ year, yearsAgo, isCurrent: yearsAgo === yearsago })
  }
  years.reverse()

  const buildUrl = (params) => {
    const query = new URLSearchParams()
    if (params.yearsago) query.set('yearsago', params.yearsago)
    if (params.startat) query.set('startat', params.startat)
    // Use title-based URL (relative to current page) instead of node ID
    return `?${query.toString()}`
  }

  return (
    <div className="document">
      <p style={{ textAlign: 'center' }}>Turn the clock back!</p>
      <br /><br />

      <ul>
        {nodes.map((writeup, idx) => (
          <li key={idx}>
            ({writeup.parent && <LinkNode nodeId={writeup.parent.node_id} title="full" />}) -{' '}
            <LinkNode nodeId={writeup.node_id} title={writeup.parent?.title} /> by{' '}
            <LinkNode nodeId={writeup.author?.node_id} title={writeup.author?.title} />{' '}
            <small>
              entered on {writeup.createtime && new Date(writeup.createtime).toLocaleDateString()}
            </small>
          </li>
        ))}
      </ul>

      <p>
        {count} writeups submitted {yearsago === 1 ? 'a year' : `${yearsago} years`} ago today
      </p>

      <div style={{ textAlign: 'center' }}>
        <table width="70%" style={{ margin: '0 auto' }}>
          <tbody>
            <tr>
              <td width="50%" style={{ textAlign: 'center' }}>
                {hasPrev ? (
                  <a href={buildUrl({ yearsago, startat: startat - perPage })}>
                    {startat - perPage}-{startat}
                  </a>
                ) : (
                  <span>{startat - perPage}-{startat}</span>
                )}
              </td>
              <td width="50%" style={{ textAlign: 'center' }}>
                {hasNext ? (
                  <a href={buildUrl({ yearsago, startat: startat + perPage })}>
                    {startat + perPage}-{Math.min(startat + perPage * 2, count)}
                  </a>
                ) : (
                  <span>(end of list)</span>
                )}
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div style={{ textAlign: 'center' }}>
        <hr style={{ width: '200px' }} />
      </div>

      <p style={{ textAlign: 'center' }}>
        {years.map((y, idx) => (
          <React.Fragment key={y.year}>
            {idx > 0 && ' | '}
            {y.isCurrent ? (
              <strong>{y.year}</strong>
            ) : (
              <a href={buildUrl({ yearsago: y.yearsAgo })}>{y.year}</a>
            )}
          </React.Fragment>
        ))}
      </p>
    </div>
  )
}

export default AYearAgoToday
