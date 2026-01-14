import React, { useState, useEffect } from 'react'
import ContentItem from './ContentItem'
import NewWriteupsCard from '../NewWriteupsCard'

/**
 * WelcomeToEverything - Main page content for logged-in users
 *
 * Desktop: Two-column layout with cards on left, Cream of Cool on right
 * Mobile: Stacked single column
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

  if (isMobile) {
    return <WelcomeToEverythingMobile
      is_guest={is_guest}
      daylogs={daylogs}
      coolnodes={coolnodes}
      staffpicks={staffpicks}
      creamofthecool={creamofthecool}
      news={news}
      newwriteups={newwriteups}
    />
  }

  // Desktop layout
  return (
    <div id="welcomecontent" className="welcome-container welcome-container--desktop">
      <div className="welcome-message">
        Everything2 is a collection of user-submitted writings about
        more or less everything. Spend some time looking around and reading, or{' '}
        <a href="/title/Everything2%20Help" className="welcome-link">learn how to contribute</a>.
      </div>

      {/* Two-column desktop layout */}
      <div className="welcome-desktop-grid">
        {/* Left column: Cards in 2x2 grid */}
        <div className="welcome-left-column">
          <div className="welcome-cards-grid">
            {/* New Writeups */}
            {newwriteups.length > 0 && (
              <NewWriteupsCard
                writeups={newwriteups}
                isMobile={false}
                limit={10}
              />
            )}

            {/* Logs */}
            {daylogs.length > 0 && (
              <div className="welcome-card">
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
            )}

            {/* Cool User Picks */}
            {coolnodes.length > 0 && (
              <div className="welcome-card">
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
            )}

            {/* Staff Picks */}
            {!is_guest && staffpicks.length > 0 && (
              <div className="welcome-card">
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
            )}
          </div>
        </div>

        {/* Right column: Cream of the Cool */}
        {creamofthecool.length > 0 && (
          <div className="welcome-right-column">
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
          </div>
        )}
      </div>

      {/* News for Noders - full width at bottom */}
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

/**
 * Mobile layout - stacked single column
 */
const WelcomeToEverythingMobile = ({
  is_guest,
  daylogs,
  coolnodes,
  staffpicks,
  creamofthecool,
  news,
  newwriteups
}) => {
  return (
    <div id="welcomecontent" className="welcome-container welcome-container--mobile">
      <div className="welcome-message welcome-message--mobile">
        Everything2 is a collection of user-submitted writings about
        more or less everything. Spend some time looking around and reading, or{' '}
        <a href="/title/Everything2%20Help" className="welcome-link">learn how to contribute</a>.
      </div>

      <div className="welcome-cards-row welcome-cards-row--mobile">
        {newwriteups.length > 0 && (
          <NewWriteupsCard
            writeups={newwriteups}
            isMobile={true}
            limit={10}
          />
        )}

        {daylogs.length > 0 && (
          <div className="welcome-card welcome-card--mobile">
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
        )}

        {coolnodes.length > 0 && (
          <div className="welcome-card welcome-card--mobile">
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
        )}

        {!is_guest && staffpicks.length > 0 && (
          <div className="welcome-card welcome-card--mobile">
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
        )}
      </div>

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
