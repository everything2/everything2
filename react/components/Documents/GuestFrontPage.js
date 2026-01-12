import React, { useMemo } from 'react'
import { renderE2Content } from '../Editor/E2HtmlSanitizer'
import ContentItem from './ContentItem'
import NewWriteupsCard from '../NewWriteupsCard'
import { useIsMobile } from '../../hooks/useMediaQuery'

/**
 * GuestFrontPage - Landing page for non-authenticated users
 *
 * Displays: Hero section with marketing copy, Best of The Week content,
 * and News for Noders section in a two-column layout (stacked on mobile)
 */
const GuestFrontPage = ({ data, e2 }) => {
  const {
    hero = {},
    bestofweek = [],
    news = []
  } = data || {}

  // Get new writeups from e2 global state (always loaded for all users)
  const newwriteups = e2?.newWriteups || []

  const isMobile = useIsMobile()

  const heroClass = isMobile ? 'guest-hero guest-hero--mobile' : 'guest-hero'
  const headlineClass = isMobile ? 'guest-hero-headline guest-hero-headline--mobile' : 'guest-hero-headline'
  const gridClass = isMobile ? 'guest-content-grid guest-content-grid--mobile' : 'guest-content-grid'
  const secondaryClass = isMobile ? 'guest-secondary-column guest-secondary-column--mobile' : 'guest-secondary-column'

  return (
    <div className="guest-container">
      {/* Hero Section */}
      <section className={heroClass}>
        <h1 className={headlineClass}>
          Everything<span>2</span>
        </h1>
        <p className="guest-hero-tagline">{hero.tagline}</p>
        <p className="guest-hero-description">{hero.description}</p>
        {hero.cta && (
          <a href={hero.cta.url} className="guest-cta-button">
            {hero.cta.text}
          </a>
        )}
      </section>

      {/* New Writeups card - below hero */}
      {newwriteups.length > 0 && (
        <section className="guest-new-writeups-section">
          <NewWriteupsCard writeups={newwriteups} isMobile={isMobile} limit={10} />
        </section>
      )}

      {/* Two-column content area (stacked on mobile) */}
      <div className={gridClass}>
        {/* Best of The Week - Primary column */}
        <section className="guest-primary-column">
          <h2 className="guest-section-title">
            <a href="/title/Cool%20Archive" className="guest-section-link">
              The Best of The Week
            </a>
          </h2>
          <div className="guest-card-grid">
            {bestofweek.map((item, index) => (
              <FeaturedCard key={item.node_id || index} item={item} />
            ))}
          </div>
        </section>

        {/* News for Noders - Secondary column */}
        <aside className={secondaryClass}>
          <h2 className="guest-section-title">
            <a href="/title/News%20for%20Noders.%20Stuff%20that%20matters." className="guest-section-link">
              News for Noders
            </a>
          </h2>
          <div className="guest-news-list">
            {news.map((item, index) => (
              <ContentItem
                key={item.node_id || index}
                item={item}
                showTitle={true}
                showByline={true}
                showDate={true}
                showLinkedBy={true}
                showContent={true}
              />
            ))}
          </div>
        </aside>
      </div>
    </div>
  )
}

/**
 * FeaturedCard - A card component for featured writeups
 */
const FeaturedCard = ({ item }) => {
  const { node_id, parent, author, type, content = '', truncated } = item

  const displayTitle = parent ? parent.title : ''
  const linkTarget = parent ? `/node/${parent.node_id}` : `/node/${node_id}`

  // Process content through E2 sanitizer
  const processedContent = useMemo(() => {
    if (!content) return ''
    const { html } = renderE2Content(content)
    return html
  }, [content])

  return (
    <article className="guest-featured-card">
      <header className="guest-card-header">
        <a href={linkTarget} className="guest-card-title">
          {displayTitle}
        </a>
        {type && (
          <span className="guest-card-type">
            <a href={`/node/${node_id}`}>{type}</a>
          </span>
        )}
      </header>
      {author && (
        <div className="guest-card-byline">
          by <a href={`/user/${encodeURIComponent(author.title)}`} className="guest-card-author">
            {author.title}
          </a>
        </div>
      )}
      {content && (
        <div
          className="guest-card-content"
          dangerouslySetInnerHTML={{ __html: processedContent }}
        />
      )}
      {(truncated === true || truncated === 1) && (
        <div className="guest-card-more">
          <a href={`/node/${node_id}`} className="guest-card-more-link">Read more</a>
        </div>
      )}
    </article>
  )
}

export default GuestFrontPage
