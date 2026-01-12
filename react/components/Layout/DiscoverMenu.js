import React, { useState, useEffect } from 'react'

/**
 * DiscoverMenu - Bottom sheet menu for content discovery
 *
 * Shows content discovery options with inline display for New Writeups:
 * - New Writeups (loads inline from API, expandable)
 * - User Search
 * - Editor's Picks (Page of Cool)
 * - Cool Archive
 * - Random Node
 */
const DiscoverMenu = ({ onClose }) => {
  const [showNewWriteups, setShowNewWriteups] = useState(false)
  const [newWriteups, setNewWriteups] = useState([])
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    if (showNewWriteups && newWriteups.length === 0) {
      setLoading(true)
      fetch('/api/newwriteups')
        .then(res => res.json())
        .then(data => {
          if (Array.isArray(data)) {
            setNewWriteups(data.slice(0, 15)) // Show first 15
          }
          setLoading(false)
        })
        .catch(() => setLoading(false))
    }
  }, [showNewWriteups, newWriteups.length])

  // Menu items after New Writeups (which is special/expandable)
  const menuItems = [
    { label: 'User Search', href: '/title/Everything+User+Search' },
    { label: "Editor's Picks", href: '/title/Page+of+Cool' },
    { label: 'Cool Archive', href: '/title/Cool+Archive' },
    { label: 'Random Node', href: '/?op=randomnode' }
  ]

  return (
    <div className="discover-menu-overlay" onClick={onClose}>
      <div className="discover-menu" onClick={e => e.stopPropagation()}>
        <div className="discover-menu-handle" />
        <h3 className="discover-menu-title">Discover</h3>

        {/* New Writeups - expandable section */}
        <button
          type="button"
          className="discover-menu-button"
          onClick={() => setShowNewWriteups(!showNewWriteups)}
        >
          New Writeups {showNewWriteups ? '▲' : '▼'}
        </button>

        {showNewWriteups && (
          <div className="discover-writeups-list">
            {loading ? (
              <div className="discover-loading">Loading...</div>
            ) : newWriteups.length > 0 ? (
              newWriteups.map(wu => (
                <a
                  key={wu.node_id}
                  href={`/node/${wu.node_id}`}
                  className="discover-writeup-item"
                >
                  <span className="discover-writeup-title">
                    {wu.parent?.title || wu.title?.replace(/\s*\([^)]+\)$/, '') || 'Untitled'}
                  </span>
                  <span className="discover-writeup-meta">
                    by {wu.author?.title || 'anonymous'}
                  </span>
                </a>
              ))
            ) : (
              <div className="discover-loading">No new writeups</div>
            )}
            <a href="/title/Writeups+by+Type" className="discover-see-more">
              See all new writeups →
            </a>
          </div>
        )}

        {menuItems.map(item => (
          <a
            key={item.label}
            href={item.href}
            className="discover-menu-item"
          >
            {item.label}
          </a>
        ))}
      </div>
    </div>
  )
}

export default DiscoverMenu
