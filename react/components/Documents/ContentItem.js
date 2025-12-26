import React, { useMemo } from 'react'
import { renderE2Content } from '../Editor/E2HtmlSanitizer'

/**
 * ContentItem - Renders a content item (writeup, news post, etc.)
 *
 * Used by front page components to display content snippets with
 * consistent formatting for title, author, type, date, and content.
 *
 * Props:
 * - item: The content item object with node_id, title, author, content, etc.
 * - showTitle: Show the item title as a link
 * - showType: Show the writeup type (e.g., "thing", "idea")
 * - showByline: Show "by [author]" line
 * - showDate: Show the createtime/publishtime
 * - showLinkedBy: Show who linked the item (for weblogs)
 * - showContent: Show the content body
 * - maxLength: Max content length before truncation (0 = no limit)
 */
const ContentItem = ({
  item,
  showTitle = false,
  showType = false,
  showByline = false,
  showDate = false,
  showLinkedBy = false,
  showContent = true,
  maxLength = 0
}) => {
  if (!item) return null

  const {
    node_id,
    title,
    parent,
    author,
    type,
    content = '',
    truncated = false,
    linkedby,
    createtime
  } = item

  // Determine the title to display and link target
  const displayTitle = parent ? parent.title : title
  const linkTarget = parent ? `/node/${parent.node_id}` : `/node/${node_id}`

  // Format date if needed
  const formatDate = (dateStr) => {
    if (!dateStr) return ''
    const date = new Date(dateStr)
    if (isNaN(date.getTime())) return ''
    return date.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric'
    })
  }

  // Process content through E2 sanitizer and link parser
  // This handles raw doctext from the server and converts E2 [link] syntax
  const processedContent = useMemo(() => {
    if (!content) return ''
    const { html } = renderE2Content(content)
    return html
  }, [content])

  return (
    <div className="item">
      <div className="contentinfo contentheader">
        {showTitle && displayTitle && (
          <a href={linkTarget} className="title">
            {displayTitle}
          </a>
        )}
        {!showTitle && parent && (
          <a
            href={`${linkTarget}#${encodeURIComponent(author?.title || '')}`}
            className="title"
          >
            {displayTitle}
          </a>
        )}
        {showType && type && (
          <span className="type">
            (<a href={`/node/${node_id}`}>{type}</a>)
          </span>
        )}
        {showByline && author && (
          <cite>
            by <a href={`/user/${encodeURIComponent(author.title)}`} className="author">
              {author.title}
            </a>
          </cite>
        )}
        {showDate && createtime && (
          <span className="date">{formatDate(createtime)}</span>
        )}
        {showLinkedBy && linkedby && (
          <span className="linkedby">
            (linked by <a href={`/user/${encodeURIComponent(linkedby)}`}>{linkedby}</a>)
          </span>
        )}
      </div>

      {showContent && content && (
        <>
          <div
            className="content"
            dangerouslySetInnerHTML={{ __html: processedContent }}
          />
          {(truncated === true || truncated === 1) && (
            <div className="morelink">
              (<a href={`/node/${node_id}`}>more</a>)
            </div>
          )}
        </>
      )}
    </div>
  )
}

export default ContentItem
