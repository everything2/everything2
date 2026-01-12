import React, { useState, useCallback } from 'react'
import LinkNode from '../LinkNode'
import { useIsMobile } from '../../hooks/useMediaQuery'

const baseStyles = {
  container: {
    maxWidth: '900px',
    margin: '0 auto',
    padding: '20px',
  },
  filterForm: {
    marginBottom: '20px',
    padding: '15px',
    backgroundColor: '#f8f9fa',
    borderRadius: '4px',
  },
  formRow: {
    display: 'flex',
    alignItems: 'center',
    marginBottom: '10px',
    gap: '10px',
  },
  label: {
    fontWeight: 'bold',
    minWidth: '120px',
  },
  input: {
    padding: '6px 10px',
    border: '1px solid #ccc',
    borderRadius: '4px',
    fontSize: '14px',
    width: '200px',
  },
  select: {
    padding: '6px 10px',
    border: '1px solid #ccc',
    borderRadius: '4px',
    fontSize: '14px',
  },
  hint: {
    fontSize: '12px',
    color: '#666',
    marginLeft: '10px',
  },
  button: {
    padding: '8px 16px',
    backgroundColor: '#4060b0',
    color: 'white',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
    fontSize: '14px',
    fontWeight: 'bold',
  },
  table: {
    width: '100%',
    borderCollapse: 'collapse',
    marginBottom: '20px',
  },
  th: {
    backgroundColor: '#f0f0f0',
    padding: '10px',
    textAlign: 'left',
    borderBottom: '2px solid #ccc',
    fontWeight: 'bold',
  },
  thCenter: {
    backgroundColor: '#f0f0f0',
    padding: '10px',
    textAlign: 'center',
    borderBottom: '2px solid #ccc',
    fontWeight: 'bold',
  },
  td: {
    padding: '8px 10px',
    borderBottom: '1px solid #eee',
  },
  tdCenter: {
    padding: '8px 10px',
    borderBottom: '1px solid #eee',
    textAlign: 'center',
  },
  oddRow: {
    backgroundColor: '#fff',
  },
  evenRow: {
    backgroundColor: '#f9f9f9',
  },
  yesText: {
    fontWeight: 'bold',
    color: '#28a745',
  },
  noText: {
    color: '#666',
  },
  pagination: {
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
    gap: '15px',
    marginTop: '20px',
  },
  pageLink: {
    color: '#4060b0',
    textDecoration: 'none',
    cursor: 'pointer',
  },
  currentPage: {
    fontWeight: 'bold',
  },
  emptyMessage: {
    padding: '20px',
    textAlign: 'center',
    fontStyle: 'italic',
    color: '#666',
  },
  usergroupTag: {
    fontSize: '12px',
    color: '#666',
  },
}

const DisplayCategories = ({ data }) => {
  const isMobile = useIsMobile()
  const initialData = data.displayCategories || {}
  const {
    categories: initialCategories,
    page: initialPage,
    pageSize,
    hasMore: initialHasMore,
    maintainerName: initialMaintainer,
    sortOrder: initialOrder,
    isGuest,
  } = initialData

  const [categories, setCategories] = useState(initialCategories || [])
  const [page, setPage] = useState(initialPage || 0)
  const [hasMore, setHasMore] = useState(initialHasMore)
  const [maintainerName, setMaintainerName] = useState(initialMaintainer || '')
  const [sortOrder, setSortOrder] = useState(initialOrder || '')
  const [loading, setLoading] = useState(false)

  const loadPage = useCallback(async (newPage, newMaintainer, newOrder) => {
    setLoading(true)

    // Build URL with query params
    const params = new URLSearchParams()
    params.set('p', newPage.toString())
    if (newMaintainer) params.set('m', newMaintainer)
    if (newOrder) params.set('o', newOrder)

    try {
      const response = await fetch(`/title/Display%20Categories?${params.toString()}`, {
        headers: { 'Accept': 'application/json' },
        credentials: 'include',
      })

      if (response.ok) {
        const result = await response.json()
        if (result.contentData?.displayCategories) {
          const newData = result.contentData.displayCategories
          setCategories(newData.categories || [])
          setPage(newData.page)
          setHasMore(newData.hasMore)
        }
      }
    } catch (err) {
      console.error('Failed to load categories:', err)
    } finally {
      setLoading(false)
    }
  }, [])

  const handleSubmit = useCallback((e) => {
    e.preventDefault()
    // Update URL and reload with new filters
    const params = new URLSearchParams()
    if (maintainerName) params.set('m', maintainerName)
    if (sortOrder) params.set('o', sortOrder)

    window.location.href = `/title/Display%20Categories?${params.toString()}`
  }, [maintainerName, sortOrder])

  const handlePrevPage = useCallback(() => {
    if (page > 0) {
      const params = new URLSearchParams()
      params.set('p', (page - 1).toString())
      if (maintainerName) params.set('m', maintainerName)
      if (sortOrder) params.set('o', sortOrder)
      window.location.href = `/title/Display%20Categories?${params.toString()}`
    }
  }, [page, maintainerName, sortOrder])

  const handleNextPage = useCallback(() => {
    if (hasMore) {
      const params = new URLSearchParams()
      params.set('p', (page + 1).toString())
      if (maintainerName) params.set('m', maintainerName)
      if (sortOrder) params.set('o', sortOrder)
      window.location.href = `/title/Display%20Categories?${params.toString()}`
    }
  }, [page, hasMore, maintainerName, sortOrder])

  // Responsive styles
  const styles = {
    ...baseStyles,
    container: {
      ...baseStyles.container,
      padding: isMobile ? '12px' : '20px',
    },
    formRow: {
      display: 'flex',
      flexDirection: isMobile ? 'column' : 'row',
      alignItems: isMobile ? 'stretch' : 'center',
      marginBottom: '10px',
      gap: isMobile ? '4px' : '10px',
    },
    label: {
      fontWeight: 'bold',
      minWidth: isMobile ? 'auto' : '120px',
    },
    input: {
      padding: '8px 10px',
      border: '1px solid #ccc',
      borderRadius: '4px',
      fontSize: '14px',
      width: isMobile ? '100%' : '200px',
      boxSizing: 'border-box',
    },
    select: {
      padding: '8px 10px',
      border: '1px solid #ccc',
      borderRadius: '4px',
      fontSize: '14px',
      width: isMobile ? '100%' : 'auto',
      boxSizing: 'border-box',
    },
    hint: {
      fontSize: '12px',
      color: '#666',
      marginLeft: isMobile ? '0' : '10px',
      marginTop: isMobile ? '2px' : '0',
    },
    button: {
      ...baseStyles.button,
      width: isMobile ? '100%' : 'auto',
      marginTop: isMobile ? '10px' : '0',
    },
  }

  return (
    <div style={styles.container}>
      <form onSubmit={handleSubmit} style={baseStyles.filterForm}>
        <div style={styles.formRow}>
          <label style={styles.label}>Maintained By:</label>
          <input
            type="text"
            value={maintainerName}
            onChange={(e) => setMaintainerName(e.target.value)}
            style={styles.input}
            placeholder="Username or usergroup"
          />
          {!isMobile && <span style={styles.hint}>(leave blank for all)</span>}
        </div>
        {isMobile && <span style={styles.hint}>Leave blank to list all categories</span>}
        <div style={styles.formRow}>
          <label style={styles.label}>Sort Order:</label>
          <select
            value={sortOrder}
            onChange={(e) => setSortOrder(e.target.value)}
            style={styles.select}
          >
            <option value="">Category Name</option>
            <option value="m">Maintainer</option>
          </select>
        </div>
        <button type="submit" style={styles.button} disabled={loading}>
          {loading ? 'Loading...' : 'Submit'}
        </button>
      </form>

      <table style={baseStyles.table}>
        <thead>
          <tr>
            <th style={baseStyles.th}>Category</th>
            <th style={baseStyles.thCenter}>Maintainer</th>
            {!isGuest && <th style={baseStyles.thCenter}>Can I Contribute?</th>}
          </tr>
        </thead>
        <tbody>
          {categories.length === 0 ? (
            <tr>
              <td colSpan={isGuest ? 2 : 3} style={baseStyles.emptyMessage}>
                No categories found!
              </td>
            </tr>
          ) : (
            categories.map((cat, index) => (
              <tr key={cat.node_id} style={index % 2 === 0 ? baseStyles.oddRow : baseStyles.evenRow}>
                <td style={baseStyles.td}>
                  <LinkNode type="category" title={cat.title} />
                </td>
                <td style={baseStyles.tdCenter}>
                  {cat.is_public ? (
                    'Everyone'
                  ) : (
                    <>
                      <LinkNode
                        type={cat.is_usergroup ? 'usergroup' : 'user'}
                        title={cat.maintainer_name}
                      />
                      {cat.is_usergroup && (
                        <span style={baseStyles.usergroupTag}> (usergroup)</span>
                      )}
                    </>
                  )}
                </td>
                {!isGuest && (
                  <td style={baseStyles.tdCenter}>
                    {cat.can_contribute ? (
                      <span style={baseStyles.yesText}>Yes!</span>
                    ) : (
                      <span style={baseStyles.noText}>No</span>
                    )}
                  </td>
                )}
              </tr>
            ))
          )}
        </tbody>
      </table>

      {(page > 0 || hasMore) && (
        <div style={baseStyles.pagination}>
          {page > 0 ? (
            <a onClick={handlePrevPage} style={baseStyles.pageLink}>
              &lt;&lt; Previous
            </a>
          ) : (
            <span style={{ color: '#ccc' }}>&lt;&lt; Previous</span>
          )}
          <span>|</span>
          <span style={baseStyles.currentPage}>Page {page + 1}</span>
          <span>|</span>
          {hasMore ? (
            <a onClick={handleNextPage} style={baseStyles.pageLink}>
              Next &gt;&gt;
            </a>
          ) : (
            <span style={{ color: '#ccc' }}>Next &gt;&gt;</span>
          )}
        </div>
      )}
    </div>
  )
}

export default DisplayCategories
