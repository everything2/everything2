import React, { useState } from 'react'
import { useIsMobile } from '../../hooks/useMediaQuery'

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
  const isMobile = useIsMobile()
  const { editors = [], initial_coolnodes = [], pagination: initialPagination } = data || {}

  // State
  const [selectedEditor, setSelectedEditor] = useState('')
  const [editorEndorsements, setEditorEndorsements] = useState(null)
  const [loadingEndorsements, setLoadingEndorsements] = useState(false)
  const [coolnodes, setCoolnodes] = useState(initial_coolnodes)
  const [pagination, setPagination] = useState(initialPagination || { offset: 0, limit: 50, total: 0 })
  const [loadingNodes, setLoadingNodes] = useState(false)

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

  const containerClass = isMobile ? 'page-of-cool page-of-cool--mobile' : 'page-of-cool'
  const introClass = isMobile ? 'page-of-cool__intro page-of-cool__intro--mobile' : 'page-of-cool__intro'

  return (
    <div className={containerClass}>
      {/* Intro - no H1 since PageHeader already renders the title */}
      <p className={introClass}>
        Browse through the latest editor selections below, or choose a specific editor
        (or former editor) to see what they've endorsed.
      </p>

      {/* Editor Selector Section */}
      <div className="page-of-cool__section">
        <h2 className="page-of-cool__section-title">Editor Endorsements</h2>
        <div className="page-of-cool__filter-box">
          <label className="page-of-cool__filter-label">
            Select an editor:
          </label>
          <select
            value={selectedEditor}
            onChange={handleEditorChange}
            className="page-of-cool__select"
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
          <div className="page-of-cool__loading">
            Loading endorsements...
          </div>
        )}

        {editorEndorsements && !loadingEndorsements && (
          <div className="page-of-cool__endorsement-box">
            <p className="page-of-cool__count">
              <a href={`/user/${editorEndorsements.editor_name}`} className="page-of-cool__link">
                {editorEndorsements.editor_name}
              </a>
              {' '}has endorsed {editorEndorsements.count} node{editorEndorsements.count !== 1 ? 's' : ''}
            </p>
            {editorEndorsements.nodes && editorEndorsements.nodes.length > 0 && (
              <ul className="page-of-cool__list">
                {editorEndorsements.nodes.map((node, idx) => (
                  <li key={idx} className="page-of-cool__list-item">
                    <a href={`/node/${node.node_id}`} className="page-of-cool__link">
                      {node.title}
                    </a>
                    {node.writeup_count !== undefined && (
                      <span className="page-of-cool__meta">
                        {' '}- {node.writeup_count} writeup{node.writeup_count !== 1 ? 's' : ''}
                      </span>
                    )}
                    {node.type && node.type !== 'e2node' && (
                      <span className="page-of-cool__meta">
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
      <div className="page-of-cool__section">
        <h2 className="page-of-cool__section-title">Latest Cool Nodes</h2>

        {loadingNodes ? (
          <div className="page-of-cool__loading page-of-cool__loading--large">
            Loading...
          </div>
        ) : (
          <>
            <table className="page-of-cool__table">
              <thead>
                <tr>
                  <th className="page-of-cool__th">Title</th>
                  <th className="page-of-cool__th page-of-cool__th--cooler">Cooled by</th>
                </tr>
              </thead>
              <tbody>
                {coolnodes.map((node, idx) => (
                  <tr key={node.node_id || idx}>
                    <td className={`page-of-cool__td${idx % 2 === 1 ? ' page-of-cool__td--odd' : ''}`}>
                      <a href={`/node/${node.node_id}`} className="page-of-cool__link">
                        {node.title}
                      </a>
                    </td>
                    <td className={`page-of-cool__td${idx % 2 === 1 ? ' page-of-cool__td--odd' : ''}`}>
                      {node.cooled_by_name ? (
                        <a href={`/user/${node.cooled_by_name}`} className="page-of-cool__link">
                          {node.cooled_by_name}
                        </a>
                      ) : (
                        <span className="page-of-cool__empty-cell">—</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>

            {/* Pagination */}
            <div className="page-of-cool__pagination">
              <button
                onClick={() => goToPage(pagination.offset - pagination.limit)}
                disabled={pagination.offset === 0}
                className="page-of-cool__btn"
              >
                ← Previous {pagination.limit}
              </button>

              <span className="page-of-cool__pagination-info">
                Showing {pagination.offset + 1} - {Math.min(pagination.offset + pagination.limit, pagination.total)} of {pagination.total}
              </span>

              <button
                onClick={() => goToPage(pagination.offset + pagination.limit)}
                disabled={pagination.offset + pagination.limit >= pagination.total}
                className="page-of-cool__btn"
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
