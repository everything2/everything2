import React, { useState, useCallback } from 'react'
import LinkNode from '../LinkNode'
import { useIsMobile } from '../../hooks/useMediaQuery'

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

  const containerClass = isMobile
    ? 'display-categories display-categories--mobile'
    : 'display-categories'
  const formRowClass = isMobile
    ? 'display-categories__form-row display-categories__form-row--mobile'
    : 'display-categories__form-row'
  const labelClass = isMobile
    ? 'display-categories__label display-categories__label--mobile'
    : 'display-categories__label'
  const inputClass = isMobile
    ? 'display-categories__input display-categories__input--mobile'
    : 'display-categories__input'
  const selectClass = isMobile
    ? 'display-categories__select display-categories__select--mobile'
    : 'display-categories__select'
  const hintClass = isMobile
    ? 'display-categories__hint display-categories__hint--mobile'
    : 'display-categories__hint'
  const btnClass = isMobile
    ? 'display-categories__btn display-categories__btn--mobile'
    : 'display-categories__btn'

  return (
    <div className={containerClass}>
      <form onSubmit={handleSubmit} className="display-categories__filter-form">
        <div className={formRowClass}>
          <label className={labelClass}>Maintained By:</label>
          <input
            type="text"
            value={maintainerName}
            onChange={(e) => setMaintainerName(e.target.value)}
            className={inputClass}
            placeholder="Username or usergroup"
          />
          {!isMobile && <span className={hintClass}>(leave blank for all)</span>}
        </div>
        {isMobile && <span className={hintClass}>Leave blank to list all categories</span>}
        <div className={formRowClass}>
          <label className={labelClass}>Sort Order:</label>
          <select
            value={sortOrder}
            onChange={(e) => setSortOrder(e.target.value)}
            className={selectClass}
          >
            <option value="">Category Name</option>
            <option value="m">Maintainer</option>
          </select>
        </div>
        <button type="submit" className={btnClass} disabled={loading}>
          {loading ? 'Loading...' : 'Submit'}
        </button>
      </form>

      <table className="display-categories__table">
        <thead>
          <tr>
            <th className="display-categories__th">Category</th>
            <th className="display-categories__th display-categories__th--center">Maintainer</th>
            {!isGuest && <th className="display-categories__th display-categories__th--center">Can I Contribute?</th>}
          </tr>
        </thead>
        <tbody>
          {categories.length === 0 ? (
            <tr>
              <td colSpan={isGuest ? 2 : 3} className="display-categories__empty">
                No categories found!
              </td>
            </tr>
          ) : (
            categories.map((cat, index) => (
              <tr
                key={cat.node_id}
                className={index % 2 === 0 ? 'display-categories__row--odd' : 'display-categories__row--even'}
              >
                <td className="display-categories__td">
                  <LinkNode type="category" title={cat.title} />
                </td>
                <td className="display-categories__td display-categories__td--center">
                  {cat.is_public ? (
                    'Everyone'
                  ) : (
                    <>
                      <LinkNode
                        type={cat.is_usergroup ? 'usergroup' : 'user'}
                        title={cat.maintainer_name}
                      />
                      {cat.is_usergroup && (
                        <span className="display-categories__usergroup-tag"> (usergroup)</span>
                      )}
                    </>
                  )}
                </td>
                {!isGuest && (
                  <td className="display-categories__td display-categories__td--center">
                    {cat.can_contribute ? (
                      <span className="display-categories__yes">Yes!</span>
                    ) : (
                      <span className="display-categories__no">No</span>
                    )}
                  </td>
                )}
              </tr>
            ))
          )}
        </tbody>
      </table>

      {(page > 0 || hasMore) && (
        <div className="display-categories__pagination">
          {page > 0 ? (
            <a onClick={handlePrevPage} className="display-categories__page-link">
              &lt;&lt; Previous
            </a>
          ) : (
            <span className="display-categories__page-link--disabled">&lt;&lt; Previous</span>
          )}
          <span>|</span>
          <span className="display-categories__current-page">Page {page + 1}</span>
          <span>|</span>
          {hasMore ? (
            <a onClick={handleNextPage} className="display-categories__page-link">
              Next &gt;&gt;
            </a>
          ) : (
            <span className="display-categories__page-link--disabled">Next &gt;&gt;</span>
          )}
        </div>
      )}
    </div>
  )
}

export default DisplayCategories
