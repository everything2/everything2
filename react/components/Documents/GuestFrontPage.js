import React, { useMemo } from 'react'
import { renderE2Content } from '../Editor/E2HtmlSanitizer'
import ContentItem from './ContentItem'

/**
 * GuestFrontPage - Landing page for non-authenticated users
 *
 * Displays: Hero section with marketing copy, Best of The Week content,
 * and News for Noders section in a two-column layout
 */
const GuestFrontPage = ({ data }) => {
  const {
    hero = {},
    bestofweek = [],
    news = []
  } = data || {}

  return (
    <div style={styles.container}>
      {/* Hero Section */}
      <section style={styles.hero}>
        <h1 style={styles.heroHeadline}>
          Everything<span style={styles.hero2}>2</span>
        </h1>
        <p style={styles.heroTagline}>{hero.tagline}</p>
        <p style={styles.heroDescription}>{hero.description}</p>
        {hero.cta && (
          <a href={hero.cta.url} style={styles.ctaButton}>
            {hero.cta.text}
          </a>
        )}
      </section>

      {/* Two-column content area */}
      <div style={styles.contentGrid}>
        {/* Best of The Week - Primary column */}
        <section style={styles.primaryColumn}>
          <h2 style={styles.sectionTitle}>
            <a href="/title/Cool%20Archive" style={styles.sectionLink}>
              The Best of The Week
            </a>
          </h2>
          <div style={styles.cardGrid}>
            {bestofweek.map((item, index) => (
              <FeaturedCard key={item.node_id || index} item={item} />
            ))}
          </div>
        </section>

        {/* News for Noders - Secondary column */}
        <aside style={styles.secondaryColumn}>
          <h2 style={styles.sectionTitle}>
            <a href="/title/News%20for%20Noders.%20Stuff%20that%20matters." style={styles.sectionLink}>
              News for Noders
            </a>
          </h2>
          <div style={styles.newsList}>
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
    <article style={styles.card}>
      <header style={styles.cardHeader}>
        <a href={linkTarget} style={styles.cardTitle}>
          {displayTitle}
        </a>
        {type && (
          <span style={styles.cardType}>
            <a href={`/node/${node_id}`} style={styles.cardTypeLink}>{type}</a>
          </span>
        )}
      </header>
      {author && (
        <div style={styles.cardByline}>
          by <a href={`/user/${encodeURIComponent(author.title)}`} style={styles.cardAuthor}>
            {author.title}
          </a>
        </div>
      )}
      {content && (
        <div
          style={styles.cardContent}
          dangerouslySetInnerHTML={{ __html: processedContent }}
        />
      )}
      {(truncated === true || truncated === 1) && (
        <div style={styles.cardMore}>
          <a href={`/node/${node_id}`} style={styles.cardMoreLink}>Read more</a>
        </div>
      )}
    </article>
  )
}

const styles = {
  container: {
    maxWidth: '100%',
  },
  // Hero section
  hero: {
    textAlign: 'center',
    padding: '30px 20px 40px',
    borderBottom: '2px solid #507898',
    marginBottom: '25px',
  },
  heroHeadline: {
    fontFamily: 'Georgia, serif',
    fontSize: '48px',
    fontWeight: 'bold',
    color: '#38495e',
    margin: '0 0 10px 0',
  },
  hero2: {
    color: '#3bb5c3',
  },
  heroTagline: {
    fontSize: '20px',
    color: '#507898',
    margin: '0 0 15px 0',
    fontStyle: 'italic',
  },
  heroDescription: {
    fontSize: '16px',
    color: '#38495e',
    maxWidth: '700px',
    margin: '0 auto 20px',
    lineHeight: '1.6',
  },
  ctaButton: {
    display: 'inline-block',
    backgroundColor: '#4060b0',
    color: '#fff',
    padding: '12px 28px',
    borderRadius: '4px',
    textDecoration: 'none',
    fontSize: '16px',
    fontWeight: 'bold',
  },
  // Content grid
  contentGrid: {
    display: 'grid',
    gridTemplateColumns: '2fr 1fr',
    gap: '30px',
  },
  primaryColumn: {
    minWidth: 0,
  },
  secondaryColumn: {
    minWidth: 0,
    borderLeft: '1px solid #e0e0e0',
    paddingLeft: '25px',
  },
  sectionTitle: {
    fontSize: '20px',
    color: '#38495e',
    margin: '0 0 15px 0',
    paddingBottom: '8px',
    borderBottom: '1px solid #e8f4f8',
  },
  sectionLink: {
    color: '#4060b0',
    textDecoration: 'none',
  },
  // Card grid for featured items
  cardGrid: {
    display: 'flex',
    flexDirection: 'column',
    gap: '20px',
  },
  card: {
    backgroundColor: '#fafcfd',
    border: '1px solid #e0e8ec',
    borderRadius: '6px',
    padding: '18px',
  },
  cardHeader: {
    display: 'flex',
    alignItems: 'baseline',
    gap: '10px',
    marginBottom: '6px',
  },
  cardTitle: {
    fontSize: '18px',
    fontWeight: 'bold',
    color: '#4060b0',
    textDecoration: 'none',
    lineHeight: '1.3',
  },
  cardType: {
    fontSize: '13px',
    color: '#507898',
  },
  cardTypeLink: {
    color: '#507898',
    textDecoration: 'none',
  },
  cardByline: {
    fontSize: '14px',
    color: '#666',
    marginBottom: '12px',
  },
  cardAuthor: {
    color: '#4060b0',
    textDecoration: 'none',
  },
  cardContent: {
    fontSize: '15px',
    lineHeight: '1.6',
    color: '#38495e',
  },
  cardMore: {
    marginTop: '10px',
    paddingTop: '10px',
    borderTop: '1px solid #e8f4f8',
  },
  cardMoreLink: {
    color: '#4060b0',
    textDecoration: 'none',
    fontSize: '14px',
    fontWeight: '500',
  },
  newsList: {
    display: 'flex',
    flexDirection: 'column',
    gap: '15px',
  },
}

export default GuestFrontPage
