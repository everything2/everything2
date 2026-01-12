import React, { useState, useEffect } from 'react'
import ContentItem from './ContentItem'
import NewWriteupsCard from '../NewWriteupsCard'

/**
 * WelcomeToEverything - Main page content for logged-in users
 *
 * Displays: Welcome message, New Writeups, Logs (daylog links), Cool User Picks,
 * Staff Picks, Cream of the Cool, and News for Noders
 *
 * Card-based layout: Cards stack on mobile, float horizontally on desktop
 */
const WelcomeToEverything = ({ data, e2 }) => {
  const {
    is_guest = false,
    daylogs = [],
    coolnodes = [],
    staffpicks = [],
    creamofthecool = [],
    news = []
  } = data || {}

  const [isMobile, setIsMobile] = useState(() =>
    typeof window !== 'undefined' && window.innerWidth < 768
  )

  useEffect(() => {
    const handleResize = () => {
      setIsMobile(window.innerWidth < 768)
    }
    window.addEventListener('resize', handleResize)
    return () => window.removeEventListener('resize', handleResize)
  }, [])

  // Get new writeups from e2 global state (always loaded for all users)
  const newwriteups = e2?.newWriteups || []

  // Build cards array for horizontal layout
  const cards = []

  // New Writeups card (first position)
  if (newwriteups.length > 0) {
    cards.push(
      <NewWriteupsCard
        key="newwriteups"
        writeups={newwriteups}
        isMobile={isMobile}
        limit={10}
      />
    )
  }

  const cardClass = isMobile ? 'welcome-card welcome-card--mobile' : 'welcome-card'

  if (daylogs.length > 0) {
    cards.push(
      <div key="logs" className={cardClass}>
        <h3 className="welcome-card-header">Logs</h3>
        <div className="welcome-card-body">
          <ul className="welcome-link-list">
            {daylogs.map((log, index) => (
              <li key={index} className="welcome-link-item">
                <a
                  href={`/title/${encodeURIComponent(log.title)}`}
                  className="welcome-link"
                >
                  {log.display}
                </a>
              </li>
            ))}
          </ul>
        </div>
      </div>
    )
  }

  if (coolnodes.length > 0) {
    cards.push(
      <div key="coolpicks" className={cardClass}>
        <h3 className="welcome-card-header">Cool User Picks!</h3>
        <div className="welcome-card-body">
          <ul className="welcome-link-list">
            {coolnodes.map((node, index) => (
              <li key={node.node_id || index} className="welcome-link-item">
                <a
                  href={`/node/${node.node_id}?lastnode_id=0`}
                  className="welcome-link"
                >
                  {node.title || `node_id: ${node.node_id}`}
                </a>
              </li>
            ))}
          </ul>
          <div className="welcome-more-link">
            <a href="/title/Cool%20Archive">more →</a>
          </div>
        </div>
      </div>
    )
  }

  if (!is_guest && staffpicks.length > 0) {
    cards.push(
      <div key="staffpicks" className={cardClass}>
        <h3 className="welcome-card-header">Staff Picks</h3>
        <div className="welcome-card-body">
          <ul className="welcome-link-list">
            {staffpicks.map((pick, index) => (
              <li key={pick.node_id || index} className="welcome-link-item">
                <a
                  href={`/node/${pick.node_id}?lastnode_id=0`}
                  className="welcome-link"
                >
                  {pick.title}
                </a>
              </li>
            ))}
          </ul>
          <div className="welcome-more-link">
            <a href="/title/Page%20of%20Cool">more →</a>
          </div>
        </div>
      </div>
    )
  }

  const containerClass = isMobile
    ? 'welcome-container welcome-container--mobile'
    : 'welcome-container'

  const messageClass = isMobile
    ? 'welcome-message welcome-message--mobile'
    : 'welcome-message'

  const cardsRowClass = isMobile
    ? 'welcome-cards-row welcome-cards-row--mobile'
    : 'welcome-cards-row'

  return (
    <div id="welcomecontent" className={containerClass}>
      <div className={messageClass}>
        Everything2 is a collection of user-submitted writings about
        more or less everything. Spend some time looking around and reading, or{' '}
        <a href="/title/Everything2%20Help" className="welcome-link">learn how to contribute</a>.
      </div>

      {cards.length > 0 && (
        <div className={cardsRowClass}>
          {cards}
        </div>
      )}

      {creamofthecool.length > 0 && (
        <div className="welcome-section">
          <h3 className="welcome-section-title">
            <a href="/title/Cool%20Archive">
              Cream of the Cool
            </a>
          </h3>
          <div id="cotc">
            {creamofthecool.map((item, index) => (
              <ContentItem
                key={item.node_id || index}
                item={item}
                showType={true}
                showByline={true}
                maxLength={512}
              />
            ))}
          </div>
        </div>
      )}

      {!is_guest && news.length > 0 && (
        <div className="welcome-news-section">
          <h2 className="welcome-news-title">
            <a href="/title/News%20for%20Noders.%20Stuff%20that%20matters.">
              News for Noders
            </a>
          </h2>
          <div className="weblog">
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
        </div>
      )}
    </div>
  )
}

export default WelcomeToEverything
