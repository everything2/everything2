import React, { useState } from 'react'

/**
 * WriteupsByType - Browse writeups filtered by writeup type
 *
 * Displays a filterable, paginated list of writeups.
 * Users can filter by writeup type (thing, idea, person, etc.)
 * and control how many results to show per page.
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

  // Kernel Blue colors
  const colors = {
    primary: '#38495e',
    secondary: '#507898',
    highlight: '#4060b0',
    accent: '#3bb5c3',
    background: '#f8f9f9',
    text: '#111111'
  }

  // Check if date is valid
  const isValidDate = (dateStr) => {
    if (!dateStr) return false
    if (dateStr.startsWith('0000-00-00')) return false
    const date = new Date(dateStr)
    return !isNaN(date.getTime())
  }

  // Format date for display
  const formatDate = (dateStr) => {
    if (!isValidDate(dateStr)) return '—'
    const date = new Date(dateStr)
    return date.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    })
  }

  // Build pagination URL
  const buildPageUrl = (pageNum) => {
    const params = new URLSearchParams()
    if (current_type) params.set('wutype', current_type)
    params.set('count', current_count)
    params.set('page', pageNum)
    return `?${params.toString()}`
  }

  // Styles
  const containerStyle = {
    padding: '20px',
    maxWidth: '1000px',
    margin: '0 auto'
  }

  const filterBoxStyle = {
    backgroundColor: colors.background,
    padding: '20px',
    borderRadius: '8px',
    marginBottom: '20px',
    border: `1px solid ${colors.secondary}20`
  }

  const selectStyle = {
    padding: '8px 12px',
    border: `1px solid ${colors.secondary}`,
    borderRadius: '4px',
    fontSize: '14px',
    backgroundColor: '#fff',
    marginRight: '10px'
  }

  const buttonStyle = {
    padding: '8px 16px',
    backgroundColor: colors.highlight,
    color: '#fff',
    border: 'none',
    borderRadius: '4px',
    fontSize: '14px',
    fontWeight: '500',
    cursor: 'pointer'
  }

  const tableStyle = {
    width: '100%',
    borderCollapse: 'collapse',
    backgroundColor: '#fff',
    boxShadow: '0 1px 3px rgba(0,0,0,0.1)',
    borderRadius: '8px',
    overflow: 'hidden'
  }

  const thStyle = {
    backgroundColor: colors.primary,
    color: '#fff',
    padding: '12px 15px',
    textAlign: 'left',
    fontSize: '14px',
    fontWeight: '600'
  }

  const tdStyle = (isOdd) => ({
    padding: '10px 15px',
    borderBottom: '1px solid #eee',
    fontSize: '14px',
    backgroundColor: isOdd ? colors.background : '#fff'
  })

  const linkStyle = {
    color: colors.highlight,
    textDecoration: 'none',
    fontWeight: '500'
  }

  const typeTagStyle = {
    display: 'inline-block',
    fontSize: '12px',
    color: colors.secondary,
    marginLeft: '6px'
  }

  const paginationStyle = {
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
    gap: '15px',
    marginTop: '20px',
    padding: '15px',
    backgroundColor: colors.background,
    borderRadius: '4px'
  }

  const navLinkStyle = (disabled) => ({
    color: disabled ? '#ccc' : colors.highlight,
    textDecoration: 'none',
    fontWeight: '500',
    cursor: disabled ? 'default' : 'pointer'
  })

  const hasPrev = current_page > 0
  const hasNext = writeups.length === current_count

  return (
    <div style={containerStyle}>
      {/* Filter Form */}
      <form method="GET" action="/title/Writeups by Type" style={filterBoxStyle}>
        <fieldset style={{ border: 'none', padding: 0, margin: 0 }}>
          <legend style={{ fontWeight: '600', marginBottom: '15px', fontSize: '16px' }}>
            Choose...
          </legend>

          <div style={{ display: 'flex', flexWrap: 'wrap', alignItems: 'center', gap: '15px' }}>
            <label style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <strong>Select Writeup Type:</strong>
              <select
                name="wutype"
                value={selectedType}
                onChange={(e) => setSelectedType(Number(e.target.value))}
                style={selectStyle}
              >
                {type_options.map(opt => (
                  <option key={opt.value} value={opt.value}>{opt.label}</option>
                ))}
              </select>
            </label>

            <label style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <strong>Number of writeups to display:</strong>
              <select
                name="count"
                value={selectedCount}
                onChange={(e) => setSelectedCount(Number(e.target.value))}
                style={selectStyle}
              >
                {count_options.map(n => (
                  <option key={n} value={n}>{n}</option>
                ))}
              </select>
            </label>

            <input type="hidden" name="page" value="0" />
            <button type="submit" style={buttonStyle}>
              Get Writeups
            </button>
          </div>
        </fieldset>
      </form>

      {/* Results Table */}
      {writeups.length > 0 ? (
        <>
          <table style={tableStyle}>
            <thead>
              <tr>
                <th style={thStyle}>Title</th>
                <th style={thStyle}>Author</th>
                <th style={{ ...thStyle, textAlign: 'right' }}>Published</th>
              </tr>
            </thead>
            <tbody>
              {writeups.map((wu, idx) => (
                <tr key={wu.node_id}>
                  <td style={tdStyle(idx % 2 === 1)}>
                    {wu.parent ? (
                      <a href={`/node/${wu.parent.node_id}`} style={linkStyle}>
                        {wu.parent.title}
                      </a>
                    ) : (
                      <span style={{ color: '#999' }}>{wu.title}</span>
                    )}
                    <span style={typeTagStyle}>({wu.writeup_type})</span>
                  </td>
                  <td style={tdStyle(idx % 2 === 1)}>
                    {wu.author ? (
                      <a href={`/user/${encodeURIComponent(wu.author.title)}`} style={linkStyle}>
                        {wu.author.title}
                      </a>
                    ) : (
                      <span style={{ color: '#999' }}>—</span>
                    )}
                  </td>
                  <td style={{ ...tdStyle(idx % 2 === 1), textAlign: 'right' }}>
                    <small style={{ color: colors.secondary }}>
                      {formatDate(wu.publishtime)}
                    </small>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>

          {/* Pagination */}
          <div style={paginationStyle}>
            {hasPrev ? (
              <a href={buildPageUrl(current_page - 1)} style={navLinkStyle(false)}>
                &lt;&lt; Prev
              </a>
            ) : (
              <span style={navLinkStyle(true)}>&lt;&lt; Prev</span>
            )}

            <span style={{ fontWeight: '600' }}>
              Page {current_page + 1}
            </span>

            {hasNext ? (
              <a href={buildPageUrl(current_page + 1)} style={navLinkStyle(false)}>
                Next &gt;&gt;
              </a>
            ) : (
              <span style={navLinkStyle(true)}>Next &gt;&gt;</span>
            )}
          </div>
        </>
      ) : (
        <p style={{ textAlign: 'center', color: colors.secondary, padding: '40px' }}>
          No writeups found. Try selecting a different type or adjusting your filters.
        </p>
      )}
    </div>
  )
}

export default WriteupsByType
