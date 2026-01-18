import React from 'react'
import LinkNode from './LinkNode'
import { FaChevronLeft, FaChevronRight, FaTags } from 'react-icons/fa'

/**
 * CategoryDisplay - Displays category memberships with prev/next navigation
 *
 * Shows categories a node belongs to with navigation arrows to traverse
 * the category contents. Can be focused on a specific category via categoryId prop.
 *
 * Props:
 *   categories - Array of category objects with:
 *     - node_id, title, author_user, author_username, is_public
 *     - prev_node: { node_id, title, type } or null
 *     - next_node: { node_id, title, type } or null
 *     - position: 1-indexed position in category
 *     - total: total items in category
 *   label - Label to show before categories (default: "Categories:")
 *   focusedCategoryId - If set, only show this category (from URL param)
 *   className - Additional CSS class for styling
 *   compact - If true, use compact display (for writeup footer)
 */
const CategoryDisplay = ({
  categories,
  label = 'Categories:',
  focusedCategoryId = null,
  className = '',
  compact = false
}) => {
  // Filter to focused category if specified
  const displayCategories = focusedCategoryId
    ? categories.filter(c => c.node_id === focusedCategoryId)
    : categories

  // Don't render anything if no categories
  if (!displayCategories || displayCategories.length === 0) {
    return null
  }

  const containerClass = compact
    ? `category-display category-display--compact ${className}`.trim()
    : `category-display ${className}`.trim()

  return (
    <div className={containerClass}>
      <span className="category-display-label">
        {!compact && <FaTags className="category-display-icon" size={12} />}
        {label} ({displayCategories.length})
      </span>
      <div className="category-display-list">
        {displayCategories.map((category) => (
          <CategoryItem key={category.node_id} category={category} compact={compact} />
        ))}
      </div>
    </div>
  )
}

/**
 * CategoryItem - Single category with prev/next navigation
 */
const CategoryItem = ({ category, compact }) => {
  const { node_id, title, prev_node, next_node, position, total } = category

  // Build URL for prev/next navigation (includes category_id param for focus)
  const buildNavUrl = (node) => {
    if (!node) return null
    // Determine URL based on node type
    if (node.type === 'e2node') {
      return `/title/${encodeURIComponent(node.title)}?category_id=${node_id}`
    } else if (node.type === 'writeup') {
      return `/node/${node.node_id}?category_id=${node_id}`
    }
    // Default to node ID
    return `/node/${node.node_id}?category_id=${node_id}`
  }

  const prevUrl = buildNavUrl(prev_node)
  const nextUrl = buildNavUrl(next_node)

  if (compact) {
    return (
      <span className="category-item category-item--compact">
        {/* Prev arrow */}
        {prev_node ? (
          <a href={prevUrl} className="category-nav category-nav-prev" title={`Previous: ${prev_node.title}`}>
            <FaChevronLeft size={10} />
          </a>
        ) : (
          <span className="category-nav category-nav-prev category-nav--disabled">
            <FaChevronLeft size={10} />
          </span>
        )}

        {/* Category link with position */}
        <LinkNode nodeId={node_id} title={title} type="category" className="category-link" />
        <span className="category-position">({position}/{total})</span>

        {/* Next arrow */}
        {next_node ? (
          <a href={nextUrl} className="category-nav category-nav-next" title={`Next: ${next_node.title}`}>
            <FaChevronRight size={10} />
          </a>
        ) : (
          <span className="category-nav category-nav-next category-nav--disabled">
            <FaChevronRight size={10} />
          </span>
        )}
      </span>
    )
  }

  return (
    <div className="category-item">
      <div className="category-item-main">
        {/* Prev navigation */}
        <div className="category-nav-container">
          {prev_node ? (
            <a href={prevUrl} className="category-nav category-nav-prev" title={`Previous: ${prev_node.title}`}>
              <FaChevronLeft size={12} />
              <span className="category-nav-label">{truncateTitle(prev_node.title, 20)}</span>
            </a>
          ) : (
            <span className="category-nav category-nav-prev category-nav--disabled">
              <FaChevronLeft size={12} />
            </span>
          )}
        </div>

        {/* Category info */}
        <div className="category-info">
          <LinkNode nodeId={node_id} title={title} type="category" className="category-link" />
          <span className="category-position">{position} of {total}</span>
        </div>

        {/* Next navigation */}
        <div className="category-nav-container">
          {next_node ? (
            <a href={nextUrl} className="category-nav category-nav-next" title={`Next: ${next_node.title}`}>
              <span className="category-nav-label">{truncateTitle(next_node.title, 20)}</span>
              <FaChevronRight size={12} />
            </a>
          ) : (
            <span className="category-nav category-nav-next category-nav--disabled">
              <FaChevronRight size={12} />
            </span>
          )}
        </div>
      </div>
    </div>
  )
}

/**
 * Truncate a title to max length with ellipsis
 */
const truncateTitle = (title, maxLength) => {
  if (!title) return ''
  if (title.length <= maxLength) return title
  return title.substring(0, maxLength - 1) + '\u2026'
}

export default CategoryDisplay
