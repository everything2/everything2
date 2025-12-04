import React, { useState, useEffect } from 'react'

/**
 * PageOfCool - Browse recently cooled nodes and editor endorsements
 *
 * Features:
 * - View latest C!'ed nodes in reverse chronological order
 * - Filter by specific editor to see their endorsements
 * - Paginated results
 * - Modern Kernel Blue UI
 */
const PageOfCool = ({ data }) => {
  const { editors = [], initial_coolnodes = [], pagination: initialPagination } = data || {}

  // State
  const [selectedEditor, setSelectedEditor] = useState('')
  const [editorEndorsements, setEditorEndorsements] = useState(null)
  const [loadingEndorsements, setLoadingEndorsements] = useState(false)
  const [coolnodes, setCoolnodes] = useState(initial_coolnodes)
  const [pagination, setPagination] = useState(initialPagination || { offset: 0, limit: 50, total: 0 })
  const [loadingNodes, setLoadingNodes] = useState(false)

  // Kernel Blue colors
  const colors = {
    primary: '#38495e',
    secondary: '#507898',
    highlight: '#4060b0',
    accent: '#3bb5c3',
    background: '#f8f9f9',
    text: '#111111'
  }

  // Fetch editor endorsements
  const fetchEditorEndorsements = async (editorId) => {
    if (!editorId) {
      setEditorEndorsements(null)
      return
    }

    setLoadingEndorsements(true)
    try {
      const response = await fetch(`/api/page_of_cool/endorsements/${editorId}`)
      const result = await response.json()

      if (result.success) {
        setEditorEndorsements(result)
      }
    } catch (err) {
      console.error('Failed to load endorsements:', err)
    }
    setLoadingEndorsements(false)
  }

  // Fetch coolnodes page
  const fetchCoolnodes = async (offset) => {
    setLoadingNodes(true)
    try {
      const response = await fetch(`/api/page_of_cool/coolnodes?offset=${offset}&limit=${pagination.limit}`)
      const result = await response.json()

      if (result.success) {
        setCoolnodes(result.coolnodes || [])
        setPagination(result.pagination || pagination)
      }
    } catch (err) {
      console.error('Failed to load cool nodes:', err)
    }
    setLoadingNodes(false)
  }

  // Handle editor selection
  const handleEditorChange = (e) => {
    const editorId = e.target.value
    setSelectedEditor(editorId)
    fetchEditorEndorsements(editorId)
  }

  // Handle pagination
  const goToPage = (newOffset) => {
    fetchCoolnodes(newOffset)
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  // Styles
  const containerStyle = {
    padding: '20px',
    maxWidth: '1200px',
    margin: '0 auto'
  }

  const headerStyle = {
    marginBottom: '30px',
    borderBottom: `2px solid ${colors.primary}`,
    paddingBottom: '15px'
  }

  const titleStyle = {
    fontSize: '28px',
    color: colors.primary,
    marginBottom: '10px'
  }

  const introStyle = {
    color: colors.secondary,
    lineHeight: '1.6',
    marginBottom: '15px'
  }

  const sectionStyle = {
    marginBottom: '40px'
  }

  const sectionTitleStyle = {
    fontSize: '20px',
    color: colors.primary,
    marginBottom: '15px',
    fontWeight: '600'
  }

  const filterBoxStyle = {
    backgroundColor: colors.background,
    padding: '20px',
    borderRadius: '8px',
    marginBottom: '20px',
    border: `1px solid ${colors.secondary}20`
  }

  const selectStyle = {
    padding: '10px 15px',
    border: `1px solid ${colors.secondary}`,
    borderRadius: '4px',
    fontSize: '14px',
    backgroundColor: '#fff',
    color: colors.text,
    cursor: 'pointer',
    width: '100%',
    maxWidth: '400px'
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
    padding: '12px 15px',
    borderBottom: '1px solid #eee',
    fontSize: '14px',
    backgroundColor: isOdd ? colors.background : '#fff'
  })

  const linkStyle = {
    color: colors.highlight,
    textDecoration: 'none',
    fontWeight: '500'
  }

  const paginationStyle = {
    display: 'flex',
    justifyContent: 'space-between',
    marginTop: '20px',
    padding: '15px',
    backgroundColor: colors.background,
    borderRadius: '4px'
  }

  const buttonStyle = {
    padding: '8px 16px',
    backgroundColor: colors.highlight,
    color: '#fff',
    border: 'none',
    borderRadius: '4px',
    fontSize: '14px',
    fontWeight: '500',
    cursor: 'pointer',
    transition: 'background-color 0.2s'
  }

  const buttonDisabledStyle = {
    ...buttonStyle,
    backgroundColor: '#ccc',
    cursor: 'not-allowed'
  }

  const listStyle = {
    listStyleType: 'disc',
    marginLeft: '20px',
    lineHeight: '1.8'
  }

  const listItemStyle = {
    marginBottom: '8px',
    color: colors.text
  }

  const endorsementBoxStyle = {
    backgroundColor: '#fff',
    padding: '20px',
    borderRadius: '8px',
    boxShadow: '0 1px 3px rgba(0,0,0,0.1)',
    marginTop: '15px'
  }

  const countStyle = {
    fontSize: '16px',
    color: colors.secondary,
    marginBottom: '15px'
  }

  return (
    <div style={containerStyle}>
      {/* Header */}
      <div style={headerStyle}>
        <h1 style={titleStyle}>Page of Cool</h1>
        <p style={introStyle}>
          Browse through the latest editor selections below, or choose a specific editor
          (or former editor) to see what they've endorsed.
        </p>
      </div>

      {/* Editor Selector Section */}
      <div style={sectionStyle}>
        <h2 style={sectionTitleStyle}>Editor Endorsements</h2>
        <div style={filterBoxStyle}>
          <label style={{ display: 'block', marginBottom: '10px', fontSize: '14px', color: colors.primary, fontWeight: '600' }}>
            Select an editor:
          </label>
          <select
            value={selectedEditor}
            onChange={handleEditorChange}
            style={selectStyle}
          >
            <option value="">-- Choose an editor --</option>
            {editors.map(editor => (
              <option key={editor.node_id} value={editor.node_id}>
                {editor.title}
              </option>
            ))}
          </select>
        </div>

        {/* Editor Endorsements Results */}
        {loadingEndorsements && (
          <div style={{ textAlign: 'center', padding: '20px', color: colors.secondary }}>
            Loading endorsements...
          </div>
        )}

        {editorEndorsements && !loadingEndorsements && (
          <div style={endorsementBoxStyle}>
            <p style={countStyle}>
              <a href={`/user/${editorEndorsements.editor_name}`} style={linkStyle}>
                {editorEndorsements.editor_name}
              </a>
              {' '}has endorsed {editorEndorsements.count} node{editorEndorsements.count !== 1 ? 's' : ''}
            </p>
            {editorEndorsements.nodes && editorEndorsements.nodes.length > 0 && (
              <ul style={listStyle}>
                {editorEndorsements.nodes.map((node, idx) => (
                  <li key={idx} style={listItemStyle}>
                    <a href={`/node/${node.node_id}`} style={linkStyle}>
                      {node.title}
                    </a>
                    {node.writeup_count !== undefined && (
                      <span style={{ color: colors.secondary, fontSize: '13px' }}>
                        {' '}- {node.writeup_count} writeup{node.writeup_count !== 1 ? 's' : ''}
                      </span>
                    )}
                    {node.type && node.type !== 'e2node' && (
                      <span style={{ color: colors.secondary, fontSize: '13px' }}>
                        {' '}- ({node.type})
                      </span>
                    )}
                  </li>
                ))}
              </ul>
            )}
          </div>
        )}
      </div>

      {/* Recent Cool Nodes Section */}
      <div style={sectionStyle}>
        <h2 style={sectionTitleStyle}>Latest Cool Nodes</h2>

        {loadingNodes ? (
          <div style={{ textAlign: 'center', padding: '40px', color: colors.secondary }}>
            Loading...
          </div>
        ) : (
          <>
            <table style={tableStyle}>
              <thead>
                <tr>
                  <th style={thStyle}>Title</th>
                  <th style={{ ...thStyle, width: '250px' }}>Cooled by</th>
                </tr>
              </thead>
              <tbody>
                {coolnodes.map((node, idx) => (
                  <tr key={node.node_id || idx}>
                    <td style={tdStyle(idx % 2 === 1)}>
                      <a href={`/node/${node.node_id}`} style={linkStyle}>
                        {node.title}
                      </a>
                    </td>
                    <td style={tdStyle(idx % 2 === 1)}>
                      {node.cooled_by_name ? (
                        <a href={`/user/${node.cooled_by_name}`} style={linkStyle}>
                          {node.cooled_by_name}
                        </a>
                      ) : (
                        <span style={{ color: '#999' }}>—</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>

            {/* Pagination */}
            <div style={paginationStyle}>
              <button
                onClick={() => goToPage(pagination.offset - pagination.limit)}
                disabled={pagination.offset === 0}
                style={pagination.offset === 0 ? buttonDisabledStyle : buttonStyle}
              >
                ← Previous {pagination.limit}
              </button>

              <span style={{ fontSize: '14px', color: colors.secondary, alignSelf: 'center' }}>
                Showing {pagination.offset + 1} - {Math.min(pagination.offset + pagination.limit, pagination.total)} of {pagination.total}
              </span>

              <button
                onClick={() => goToPage(pagination.offset + pagination.limit)}
                disabled={pagination.offset + pagination.limit >= pagination.total}
                style={pagination.offset + pagination.limit >= pagination.total ? buttonDisabledStyle : buttonStyle}
              >
                Next {pagination.limit} →
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  )
}

export default PageOfCool
