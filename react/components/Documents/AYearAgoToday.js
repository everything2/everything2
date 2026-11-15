import React from 'react'
import LinkNode from '../LinkNode'
import { formatShortDate } from '../../utils/dateFormat'

/**
 * A Year Ago Today - Shows writeups from previous years on this date
 *
 * Supports pagination and year selection
 */
const AYearAgoToday = ({ data }) => {
  const { nodes = [], current_year, count, yearsago, startat } = data

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

  // Year and page links go through LinkNode, which always emits a path-absolute URL. These used to
  // be bare "?yearsago=2" hrefs, which resolve against prod's guest <base href> -- so for guests every
  // one of them went to the homepage (#4579). startat 0 is dropped from the query, as before.
  const PAGE_TITLE = 'A Year Ago Today'
  const pageLink = (display, { yearsago: ya, startat: sa }) => (
    <LinkNode title={PAGE_TITLE} display={display} params={sa ? { yearsago: ya, startat: sa } : { yearsago: ya }} />
  )

  return (
    <div className="document">
      <p className="year-ago-today__intro">Turn the clock back!</p>
      <br /><br />

      <ul>
        {nodes.map((writeup, idx) => (
          <li key={idx}>
            ({writeup.parent && <LinkNode nodeId={writeup.parent.node_id} title="full" />}) -{' '}
            <LinkNode nodeId={writeup.node_id} title={writeup.parent?.title ?? '(untitled)'} /> by{' '}
            {writeup.author
              ? <LinkNode nodeId={writeup.author.node_id} title={writeup.author.title} />
              : 'unknown'}{' '}
            <small>
              {/* UTC via dateFormat.js -- toLocaleDateString shifted late-UTC dates a day */}
              entered on {formatShortDate(writeup.createtime) ?? ''}
            </small>
          </li>
        ))}
      </ul>

      <p>
        {count} writeups submitted {yearsago === 1 ? 'a year' : `${yearsago} years`} ago today
      </p>

      <div className="year-ago-today__pagination">
        <table width="70%" className="year-ago-today__pagination-table">
          <tbody>
            <tr>
              <td width="50%" className="year-ago-today__pagination-cell">
                {hasPrev ? (
                  pageLink(`${startat - perPage}-${startat}`, { yearsago, startat: startat - perPage })
                ) : (
                  <span>{startat - perPage}-{startat}</span>
                )}
              </td>
              <td width="50%" className="year-ago-today__pagination-cell">
                {hasNext ? (
                  pageLink(`${startat + perPage}-${Math.min(startat + perPage * 2, count)}`, { yearsago, startat: startat + perPage })
                ) : (
                  <span>(end of list)</span>
                )}
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div className="year-ago-today__divider">
        <hr className="year-ago-today__divider-line" />
      </div>

      <p className="year-ago-today__years">
        {years.map((y, idx) => (
          <React.Fragment key={y.year}>
            {idx > 0 && ' | '}
            {y.isCurrent ? (
              <strong>{y.year}</strong>
            ) : (
              pageLink(String(y.year), { yearsago: y.yearsAgo })
            )}
          </React.Fragment>
        ))}
      </p>
    </div>
  )
}

export default AYearAgoToday
