import React, { useState } from 'react'
import { formatDateTime } from '../../utils/dateFormat'

/**
 * WriteupsByType - Browse writeups filtered by writeup type
 *
 * Displays a filterable, paginated list of writeups.
 * Users can filter by writeup type (thing, idea, person, etc.)
 * and control how many results to show per page.
 * Styles are in CSS classes (writeups-by-type__*)
 */
const WriteupsByType = ({ data }) => {
  const {
    writeups = [],
    type_options = [],
    count_options = [],
    current_type = 0,
    current_type_name = 'All',
    current_count = 50,
    current_page = 0
  } = data || {}

  // Form state
  const [selectedType, setSelectedType] = useState(current_type)
  const [selectedCount, setSelectedCount] = useState(current_count)

  // Date validity + UTC-aware formatting delegate to shared utility.
  // MySQL zero-date ("0000-00-00 00:00:00") is rejected explicitly.
  const isValidDate = (dateStr) => {
    if (typeof dateStr === 'string' && dateStr.startsWith('0000-00-00')) return false
    return formatDateTime(dateStr) !== null
  }
  const formatDate = (dateStr) => isValidDate(dateStr) ? formatDateTime(dateStr) : '—'

  // Build pagination URL
  const buildPageUrl = (pageNum) => {
    const params = new URLSearchParams()
    if (current_type) params.set('wutype', current_type)
    params.set('count', current_count)
    params.set('page', pageNum)
    return `?${params.toString()}`
  }

  // Helper for table cell classes
  const tdClass = (isOdd, isRight = false) => {
    let cls = 'writeups-by-type__td'
    if (isOdd) cls += ' writeups-by-type__td--odd'
    if (isRight) cls += ' writeups-by-type__td--right'
    return cls
  }

  // Coerce defensively — the server has been seen to return current_count
  // as a stringy "10" (CGI::param preserves the string flag through int()),
  // which would silently break the === comparison and disable Next.
  const pageNum  = Number(current_page) || 0
  const countNum = Number(current_count) || 0
  const hasPrev  = pageNum > 0
  const hasNext  = countNum > 0 && writeups.length === countNum

  return (
    <div className="writeups-by-type">
      {/* Filter Form */}
      <form method="GET" action="/title/Writeups by Type" className="writeups-by-type__filter-box">
        <fieldset className="writeups-by-type__fieldset">
          <legend className="writeups-by-type__legend">
            Choose...
          </legend>

          <div className="writeups-by-type__form-body">
            <label className="writeups-by-type__label">
              <strong className="writeups-by-type__label-text">Writeup Type:</strong>
              <select
                name="wutype"
                value={selectedType}
                onChange={(e) => setSelectedType(Number(e.target.value))}
                className="writeups-by-type__select writeups-by-type__select--type"
              >
                {type_options.map(opt => (
                  <option key={opt.value} value={opt.value}>{opt.label}</option>
                ))}
              </select>
            </label>

            <label className="writeups-by-type__label">
              <strong className="writeups-by-type__label-text">Results per page:</strong>
              <select
                name="count"
                value={selectedCount}
                onChange={(e) => setSelectedCount(Number(e.target.value))}
                className="writeups-by-type__select writeups-by-type__select--count"
              >
                {count_options.map(n => (
                  <option key={n} value={n}>{n}</option>
                ))}
              </select>
            </label>

            <input type="hidden" name="page" value="0" />
            <button type="submit" className="writeups-by-type__btn">
              Get Writeups
            </button>
          </div>
        </fieldset>
      </form>

      {/* Results Table */}
      {writeups.length > 0 ? (
        <>
          <table className="writeups-by-type__table">
            <thead>
              <tr>
                <th className="writeups-by-type__th">Title</th>
                <th className="writeups-by-type__th">Author</th>
                <th className="writeups-by-type__th writeups-by-type__th--right">Published</th>
              </tr>
            </thead>
            <tbody>
              {writeups.map((wu, idx) => (
                <tr key={wu.node_id}>
                  <td className={tdClass(idx % 2 === 1)}>
                    {wu.parent ? (
                      <a href={`/node/${wu.parent.node_id}`} className="writeups-by-type__link">
                        {wu.parent.title}
                      </a>
                    ) : (
                      <span className="writeups-by-type__muted">{wu.title}</span>
                    )}
                    <span className="writeups-by-type__type-tag">({wu.writeup_type})</span>
                  </td>
                  <td className={tdClass(idx % 2 === 1)}>
                    {wu.author ? (
                      <a href={`/user/${encodeURIComponent(wu.author.title)}`} className="writeups-by-type__link">
                        {wu.author.title}
                      </a>
                    ) : (
                      <span className="writeups-by-type__muted">—</span>
                    )}
                  </td>
                  <td className={tdClass(idx % 2 === 1, true)}>
                    <small className="writeups-by-type__date">
                      {formatDate(wu.publishtime)}
                    </small>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>

          {/* Pagination */}
          <div className="writeups-by-type__pagination">
            {hasPrev ? (
              <a href={buildPageUrl(pageNum - 1)} className="writeups-by-type__nav-link">
                &lt;&lt; Prev
              </a>
            ) : (
              <span className="writeups-by-type__nav-link writeups-by-type__nav-link--disabled">&lt;&lt; Prev</span>
            )}

            <span className="writeups-by-type__page-num">
              Page {pageNum + 1}
            </span>

            {hasNext ? (
              <a href={buildPageUrl(pageNum + 1)} className="writeups-by-type__nav-link">
                Next &gt;&gt;
              </a>
            ) : (
              <span className="writeups-by-type__nav-link writeups-by-type__nav-link--disabled">Next &gt;&gt;</span>
            )}
          </div>
        </>
      ) : (
        <p className="writeups-by-type__empty">
          No writeups found. Try selecting a different type or adjusting your filters.
        </p>
      )}
    </div>
  )
}

export default WriteupsByType
