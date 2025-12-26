import React from 'react'
import ContentItem from './ContentItem'

/**
 * GuestFrontPage - Landing page for non-authenticated users
 *
 * Displays: Search bar, witty tagline, Best of The Week content,
 * and News for Noders section
 */
const GuestFrontPage = ({ data }) => {
  const {
    tagline = '',
    bestofweek = [],
    news = []
  } = data || {}

  return (
    <>
      <div id="welcome_message">
        <form action="/" method="GET" id="searchform">
          <input
            type="text"
            placeholder="Search"
            name="node"
            id="searchfield"
          />
          <button type="submit" id="search">Search</button>
        </form>
        <h3 id="wit">{tagline}</h3>
      </div>

      <div id="bestnew">
        <h3 id="bestnew_title">
          <a href="/title/Cool%20Archive">The Best of The Week</a>
        </h3>
        <div className="cotc">
          {bestofweek.map((item, index) => (
            <ContentItem
              key={item.node_id || index}
              item={item}
              showType={true}
              showByline={true}
              maxLength={1024}
            />
          ))}
        </div>
      </div>

      <div id="frontpage_news">
        <h2 id="frontpage_news_title">
          <a href="/title/News%20for%20Noders.%20Stuff%20that%20matters.">News for Noders</a>
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
    </>
  )
}

export default GuestFrontPage
