import React, { useState, useEffect, useCallback, useMemo } from 'react'
import LinkNode from '../LinkNode'
import UserSearchInput from '../UserSearchInput'
import { useIsMobile } from '../../hooks/useMediaQuery'
import { formatShortDate } from '../../utils/dateFormat'

// Notable E2 contributors for suggestions
const NOTABLE_USERS = [
  'Tem42', 'wertperch', 'The Custodian', 'mauler', 'Glowing Fish',
  'DonJaime', 'Jet-Poop', 'Cletus the Foetus', 'borgo',
  'Simulacron3', 'etouffee', 'lostcauser', 'artman2003', 'Zephronias',
  'JD', 'Pandeism Fish', 'Chord', 'Yurei', 'E2D2', 'Clockmaker'
]

// Randomly select n items from an array
const selectRandom = (arr, n) => {
  const shuffled = [...arr].sort(() => Math.random() - 0.5)
  return shuffled.slice(0, n)
}

// Empty state component with randomized suggestions
const EmptyState = ({ onSelectUser }) => {
  // Randomly select 3 users on mount (useMemo ensures consistent selection during render)
  const suggestedUsers = useMemo(() => selectRandom(NOTABLE_USERS, 3), [])

  return (
    <div className="user-search__empty-state">
      <p>Enter a username above to browse their writeups.</p>
      <p className="user-search__hint">
        Try searching for some of E2's notable contributors like{' '}
        {suggestedUsers.map((name, index) => (
          <span key={name}>
            {index > 0 && (index === suggestedUsers.length - 1 ? ', or ' : ', ')}
            <button
              className="user-search__suggestion-link"
              onClick={() => onSelectUser(name)}
            >
              {name}
            </button>
          </span>
        ))}.
      </p>
    </div>
  )
}

// Legacy orderby values (old SQL-string form) -> the short codes the UI/API use now, so that
// old bookmarked links like ?orderby=node.title%20ASC still resolve. Mirrors the map the Page
// used to apply server-side (#4506).
const LEGACY_ORDERBY_MAP = {
  'writeup.publishtime DESC': 'publishtime_desc',
  'writeup.publishtime ASC': 'publishtime_asc',
  'node.title ASC': 'title_asc',
  'node.title DESC': 'title_desc',
  'node.reputation DESC': 'reputation_desc',
  'node.reputation ASC': 'reputation_asc',
  'writeup.wrtype_writeuptype ASC': 'type_asc',
  'writeup.wrtype_writeuptype DESC': 'type_desc',
  'node.hits DESC': 'hits_desc',
  'node.hits ASC': 'hits_asc',
  'RAND()': 'random',
  'node.createtime DESC': 'publishtime_desc',
  'node.createtime ASC': 'publishtime_asc'
}

// Read the search's initial state off the URL. Fully client-resolved (#4506): the Page is a pure
// gate and no longer seeds these. The username arrives in TWO shapes and we must handle both:
//   - query form:  index.pl?node=Everything User Search&usersearch=foo   (feed links, form submits)
//   - path form:   /user/foo/writeups                                    (homenode "writeups" link)
// The path form is a clean URL with NO query string, so window.location.search is empty there; we
// must recover the username from window.location.pathname, mirroring the server route-recovery in
// Everything::HTML (m{^/?user/(.+?)/writeups/?$} -> usersearch). Missing this was #4515: the
// homenode writeups link landed on the empty base widget instead of the user's writeups.
const usernameFromPath = () => {
  const m = window.location.pathname.match(/^\/?user\/(.+?)\/writeups\/?$/)
  return m ? decodeURIComponent(m[1]) : ''
}

const readInitialFromUrl = () => {
  const qs = new URLSearchParams(window.location.search)
  const rawOrderby = qs.get('orderby') || 'publishtime_desc'
  const pageParam = qs.get('page') || ''
  const filterParam = qs.get('filterhidden') || ''
  return {
    username: qs.get('usersearch') || usernameFromPath(),
    orderby: LEGACY_ORDERBY_MAP[rawOrderby] || rawOrderby,
    page: /^\d+$/.test(pageParam) ? parseInt(pageParam, 10) : 1,
    filterHidden: /^\d+$/.test(filterParam) ? parseInt(filterParam, 10) : 0
  }
}

/**
 * Everything User Search - Browse writeups by user
 * Styles in CSS: .user-search__*
 *
 * A modern, clean interface for discovering content by author.
 * Supports sorting, pagination, and filtering.
 */
const UserSearch = ({ data, user }) => {
  const isMobile = useIsMobile()
  // Seed initial search state from the URL (the Page no longer ships initial* -- #4506).
  const initial = useMemo(() => readInitialFromUrl(), [])
  const [username, setUsername] = useState(initial.username)
  const [orderby, setOrderby] = useState(initial.orderby)
  const [page, setPage] = useState(initial.page)
  const [filterHidden, setFilterHidden] = useState(initial.filterHidden)

  const [results, setResults] = useState(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)

  // Sort options for dropdown
  const sortOptions = [
    { value: 'publishtime_desc', label: 'Newest First' },
    { value: 'publishtime_asc', label: 'Oldest First' },
    { value: 'title_asc', label: 'Title A-Z' },
    { value: 'title_desc', label: 'Title Z-A' },
    { value: 'reputation_desc', label: 'Highest Reputation' },
    { value: 'reputation_asc', label: 'Lowest Reputation' },
    { value: 'cools_desc', label: 'Most Cools' },
    { value: 'cools_asc', label: 'Fewest Cools' },
    { value: 'hits_desc', label: 'Most Viewed' },
    { value: 'hits_asc', label: 'Least Viewed' },
    { value: 'type_asc', label: 'By Type' },
    { value: 'random', label: 'Random' }
  ]

  // Column sort configuration - maps column key to sort field
  const columnSortMap = {
    cools: 'cools',
    title: 'title',
    reputation: 'reputation',
    hidden: null, // Not sortable
    notes: null,  // Not sortable
    publishtime: 'publishtime',
    hits: 'hits',
    type: 'type'
  }

  // Get current sort info from orderby state
  const getCurrentSort = () => {
    const match = orderby.match(/^(\w+?)_(asc|desc)$/)
    if (match) {
      return { field: match[1], direction: match[2] }
    }
    if (orderby === 'random') {
      return { field: 'random', direction: null }
    }
    return { field: 'publishtime', direction: 'desc' }
  }

  // Handle column header click for sorting
  const handleColumnSort = (columnKey) => {
    const sortField = columnSortMap[columnKey]
    if (!sortField) return // Column not sortable

    const current = getCurrentSort()
    let newOrderby

    if (current.field === sortField) {
      // Same column - toggle direction
      newOrderby = `${sortField}_${current.direction === 'desc' ? 'asc' : 'desc'}`
    } else {
      // Different column - default to desc (except title which defaults to asc)
      const defaultDir = sortField === 'title' ? 'asc' : 'desc'
      newOrderby = `${sortField}_${defaultDir}`
    }

    setOrderby(newOrderby)
    setPage(1)
  }

  // Check if a column is the current sort column
  const isColumnSorted = (columnKey) => {
    const sortField = columnSortMap[columnKey]
    if (!sortField) return false
    const current = getCurrentSort()
    return current.field === sortField
  }

  // Get sort direction indicator
  const getSortIndicator = (columnKey) => {
    if (!isColumnSorted(columnKey)) return null
    const current = getCurrentSort()
    return current.direction === 'asc' ? ' ▲' : ' ▼'
  }

  // Check if column is sortable
  const isColumnSortable = (columnKey) => {
    return columnSortMap[columnKey] !== null
  }

  // Fetch writeups
  const fetchWriteups = useCallback(async () => {
    if (!username.trim()) {
      setResults(null)
      return
    }

    setLoading(true)
    setError(null)

    try {
      const params = new URLSearchParams({
        username: username,
        orderby: orderby,
        page: page.toString(),
        per_page: '50',
        filter_hidden: filterHidden.toString()
      })

      // Use window.location.origin to bypass any <base> tag that might be set
      const response = await fetch(`${window.location.origin}/api/user_search/?${params}`, {
        credentials: 'include'
      })

      if (!response.ok) {
        throw new Error('Failed to fetch writeups')
      }

      const data = await response.json()
      setResults(data)

      if (data.error === 'User not found') {
        setError(`User "${username}" not found`)
      }
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }, [username, orderby, page, filterHidden])

  // Single fetch trigger: username changes (covers initial mount when
  // initialUsername is set — useState seeds it, this effect picks it up).
  // Previously a separate [] -deps effect also fired on mount, producing
  // two concurrent requests for the same data on URL-loaded pages.
  useEffect(() => {
    if (username) {
      fetchWriteups()
    }
  }, [username]) // eslint-disable-line react-hooks/exhaustive-deps

  // Refetch when sort/filter/page changes (but only if we have results)
  useEffect(() => {
    if (username && results) {
      fetchWriteups()
    }
  }, [orderby, page, filterHidden]) // eslint-disable-line react-hooks/exhaustive-deps

  const handleSortChange = (e) => {
    setOrderby(e.target.value)
    setPage(1)
  }

  const handleFilterChange = (newFilter) => {
    setFilterHidden(newFilter)
    setPage(1)
  }

  // Handle user selection from UserSearchInput
  const handleUserSelect = useCallback((user) => {
    const selectedUsername = user.title
    if (selectedUsername) {
      setUsername(selectedUsername)
      setPage(1)
    }
  }, [])

  // Format date
  const formatDate = (dateStr) => formatShortDate(dateStr) ?? ''

  // Render pagination
  const renderPagination = () => {
    if (!results || results.total_pages <= 1) return null

    const pages = []
    const totalPages = results.total_pages
    const currentPage = results.page

    // Always show first page
    pages.push(1)

    // Show pages around current
    for (let i = Math.max(2, currentPage - 2); i <= Math.min(totalPages - 1, currentPage + 2); i++) {
      if (pages[pages.length - 1] !== i - 1) {
        pages.push('...')
      }
      pages.push(i)
    }

    // Always show last page
    if (totalPages > 1) {
      if (pages[pages.length - 1] !== totalPages - 1 && pages[pages.length - 1] !== '...') {
        pages.push('...')
      }
      if (pages[pages.length - 1] !== totalPages) {
        pages.push(totalPages)
      }
    }

    return (
      <div className="user-search__pagination">
        <button
          onClick={() => setPage(p => Math.max(1, p - 1))}
          disabled={currentPage === 1}
          className="user-search__page-btn"
        >
          ← Previous
        </button>

        <div className="user-search__page-numbers">
          {pages.map((p, i) => (
            p === '...' ? (
              <span key={`ellipsis-${i}`} className="user-search__ellipsis">...</span>
            ) : (
              <button
                key={p}
                onClick={() => setPage(p)}
                className={`user-search__page-number${p === currentPage ? ' user-search__page-number--active' : ''}`}
              >
                {p}
              </button>
            )
          ))}
        </div>

        <button
          onClick={() => setPage(p => Math.min(totalPages, p + 1))}
          disabled={currentPage === totalPages}
          className="user-search__page-btn"
        >
          Next →
        </button>
      </div>
    )
  }

  // Render vote indicator
  const renderVote = (vote) => {
    if (vote === undefined || vote === null) return null
    if (vote === 1) return <span className="user-search__vote-up">+</span>
    if (vote === -1) return <span className="user-search__vote-down">−</span>
    return null
  }

  // Build th class names
  const getThClassName = (columnKey, extra = '') => {
    let className = 'user-search__th'
    if (extra) className += ` ${extra}`
    if (isColumnSortable(columnKey)) className += ' user-search__th--sortable'
    if (isColumnSorted(columnKey)) className += ' user-search__th--sorted'
    return className
  }

  // Build td class names
  const getTdClassName = (columnKey, isCenter = false, isRight = false) => {
    let className = 'user-search__td'
    if (isCenter) className += ' user-search__td--center'
    if (isRight) className += ' user-search__td--right'
    if (isColumnSorted(columnKey)) className += ' user-search__td--sorted'
    return className
  }

  return (
    <div className={`document user-search${isMobile ? ' user-search--mobile' : ''}`}>
      <div className="user-search__header">
        <h1 className="user-search__title">User Writeups</h1>
        <p className="user-search__subtitle">
          Explore the collected works of Everything2 contributors
        </p>
      </div>

      {/* Search Form */}
      <div className="user-search__form">
        <div className="user-search__form-row">
          <div className="user-search__input-group">
            <label className="user-search__label">Username</label>
            <UserSearchInput
              onSelect={handleUserSelect}
              placeholder="Enter a username..."
              buttonText={loading ? 'Searching...' : 'Search'}
              disabled={loading}
              clearOnSelect={false}
            />
          </div>

          <div className="user-search__input-group">
            <label htmlFor="sort-select" className="user-search__label">Sort by</label>
            <select
              id="sort-select"
              value={orderby}
              onChange={handleSortChange}
              className="user-search__select"
            >
              {sortOptions.map(opt => (
                <option key={opt.value} value={opt.value}>{opt.label}</option>
              ))}
            </select>
          </div>
        </div>
      </div>

      {/* Error */}
      {error && (
        <div className="user-search__error">
          {error}
        </div>
      )}

      {/* Results */}
      {results && !results.error && (
        <div className="user-search__results">
          {/* Results Header */}
          <div className="user-search__results-header">
            <div className="user-search__results-info">
              <h2 className="user-search__results-title">
                <LinkNode type="user" title={results.username} />
              </h2>
              <span className="user-search__result-count">
                {results.total} writeup{results.total !== 1 ? 's' : ''}
                {results.total > 50 && ` (showing ${(results.page - 1) * 50 + 1}-${Math.min(results.page * 50, results.total)})`}
              </span>
            </div>

            {/* Filter options for self/editors */}
            {results.can_see_rep === 1 && (
              <div className="user-search__filter-buttons">
                <span className="user-search__filter-label">Show:</span>
                <button
                  onClick={() => handleFilterChange(0)}
                  className={`user-search__filter-btn${filterHidden === 0 ? ' user-search__filter-btn--active' : ''}`}
                >
                  All
                </button>
                <button
                  onClick={() => handleFilterChange(1)}
                  className={`user-search__filter-btn${filterHidden === 1 ? ' user-search__filter-btn--active' : ''}`}
                  title="Visible in New Writeups"
                >
                  Visible
                </button>
                <button
                  onClick={() => handleFilterChange(2)}
                  className={`user-search__filter-btn${filterHidden === 2 ? ' user-search__filter-btn--active' : ''}`}
                  title="Hidden from New Writeups"
                >
                  Hidden
                </button>
              </div>
            )}
          </div>

          {/* Writeups Table */}
          {results.writeups.length > 0 ? (
            <>
              <div className="user-search__table-container">
                <table className="user-search__table">
                  <thead>
                    <tr>
                      <th
                        className={getThClassName('cools')}
                        title="Sort by cools received"
                        onClick={() => handleColumnSort('cools')}
                      >
                        Cools{getSortIndicator('cools')}
                      </th>
                      <th
                        className={getThClassName('title', 'user-search__th--left')}
                        title="Sort by title"
                        onClick={() => handleColumnSort('title')}
                      >
                        Title{getSortIndicator('title')}
                      </th>
                      {(results.can_see_rep === 1 || results.is_self !== 1) && (
                        <th
                          className={getThClassName('reputation')}
                          title={results.can_see_rep === 1 ? "Sort by reputation" : "Reputation score"}
                          onClick={results.can_see_rep === 1 ? () => handleColumnSort('reputation') : undefined}
                        >
                          Reputation{results.can_see_rep === 1 && getSortIndicator('reputation')}
                        </th>
                      )}
                      {results.is_self === 1 && (
                        <th className="user-search__th" title="Vote spread (upvotes/downvotes)">Votes</th>
                      )}
                      {results.is_self !== 1 && !user?.guest && (
                        <th className="user-search__th" title="Your vote on this writeup">Your Vote</th>
                      )}
                      {results.can_see_rep === 1 && (
                        <th className="user-search__th" title="Hidden from public view (not sortable)">Hidden</th>
                      )}
                      {results.is_editor === 1 && (
                        <th className="user-search__th" title="Has editor notes (not sortable)">Notes</th>
                      )}
                      <th
                        className={getThClassName('publishtime', 'user-search__th--right')}
                        title="Sort by publish date"
                        onClick={() => handleColumnSort('publishtime')}
                      >
                        Published{getSortIndicator('publishtime')}
                      </th>
                    </tr>
                  </thead>
                  <tbody>
                    {results.writeups.map((wu, index) => (
                      <tr key={wu.node_id} className={index % 2 === 0 ? 'user-search__even-row' : 'user-search__odd-row'}>
                        <td className={getTdClassName('cools', true)}>
                          {wu.cools > 0 && (
                            <span className="user-search__cools">
                              {wu.cools}C!{wu.cools > 1 ? 's' : ''}
                            </span>
                          )}
                        </td>
                        <td className={`${getTdClassName('title')} user-search__td--title`}>
                          <LinkNode
                            type="writeup"
                            title={wu.parent_title || wu.title}
                            author={results.username}
                            display={wu.parent_title || wu.title}
                          />
                          {wu.writeup_type && (
                            <span className="user-search__writeup-type"> ({wu.writeup_type})</span>
                          )}
                        </td>
                        {(results.can_see_rep === 1 || results.is_self !== 1) && (
                          <td className={getTdClassName('reputation', true)}>
                            {wu.reputation !== undefined ? (
                              <span className={wu.reputation >= 0 ? 'user-search__rep-positive' : 'user-search__rep-negative'}>
                                {wu.reputation}
                              </span>
                            ) : (
                              <span className="user-search__rep-hidden">-</span>
                            )}
                          </td>
                        )}
                        {results.is_self === 1 && (
                          <td className="user-search__td user-search__td--center">
                            {wu.upvotes !== undefined && wu.downvotes !== undefined ? (
                              <span className="user-search__vote-spread">
                                <span className="user-search__vote-up">+{wu.upvotes}</span>
                                {' / '}
                                <span className="user-search__vote-down">−{wu.downvotes}</span>
                              </span>
                            ) : (
                              <span className="user-search__rep-hidden">-</span>
                            )}
                          </td>
                        )}
                        {results.is_self !== 1 && !user?.guest && (
                          <td className="user-search__td user-search__td--center">
                            {renderVote(wu.user_vote)}
                          </td>
                        )}
                        {results.can_see_rep === 1 && (
                          <td className="user-search__td user-search__td--center">
                            {wu.hidden ? <span className="user-search__hidden-indicator">H</span> : ''}
                          </td>
                        )}
                        {results.is_editor === 1 && (
                          <td className="user-search__td user-search__td--center">
                            {wu.has_note ? <span className="user-search__note-indicator">N</span> : ''}
                          </td>
                        )}
                        <td className={getTdClassName('publishtime', false, true)}>
                          <span className="user-search__date">{formatDate(wu.publishtime)}</span>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              {renderPagination()}
            </>
          ) : (
            <div className="user-search__no-results">
              No writeups found.
            </div>
          )}
        </div>
      )}

      {/* Empty state - shown only when no search has been performed */}
      {!results && !loading && !error && (
        <EmptyState
          onSelectUser={(name) => handleUserSelect({ title: name })}
        />
      )}
    </div>
  )
}

export default UserSearch
