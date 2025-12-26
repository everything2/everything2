import React from 'react'
import ContentItem from './ContentItem'

/**
 * WelcomeToEverything - Main page content for logged-in users
 *
 * Displays: Welcome message, Logs (daylog links), Cool User Picks,
 * Staff Picks, Cream of the Cool, and News for Noders
 */
const WelcomeToEverything = ({ data }) => {
  const {
    is_guest = false,
    daylogs = [],
    coolnodes = [],
    staffpicks = [],
    creamofthecool = [],
    news = []
  } = data || {}

  return (
    <div id="welcomecontent">
      <div id="welcome_message">
        Everything2 is a collection of user-submitted writings about
        more or less everything. Spend some time looking around and reading, or{' '}
        <a href="/title/Everything2%20Help">learn how to contribute</a>.
      </div>

      {daylogs.length > 0 && (
        <div id="loglinks">
          <h3>Logs</h3>
          <ul className="linklist">
            {daylogs.map((log, index) => (
              <li key={index} className="loglink">
                <a href={`/title/${encodeURIComponent(log.title)}`}>
                  {log.display}
                </a>
              </li>
            ))}
          </ul>
        </div>
      )}

      {coolnodes.length > 0 && (
        <div id="cooluserpicks">
          <h3>Cool User Picks!</h3>
          <ul className="linklist">
            {coolnodes.map((node, index) => (
              <li key={node.node_id || index}>
                <a href={`/node/${node.node_id}?lastnode_id=0`}>
                  {node.title || `node_id: ${node.node_id}`}
                </a>
              </li>
            ))}
          </ul>
          <div className="nodeletfoot morelink">
            (<a href="/title/Cool%20Archive">more</a>)
          </div>
        </div>
      )}

      {!is_guest && staffpicks.length > 0 && (
        <div id="staff_picks">
          <h3>Staff Picks</h3>
          <ul className="linklist">
            {staffpicks.map((pick, index) => (
              <li key={pick.node_id || index}>
                <a href={`/node/${pick.node_id}?lastnode_id=0`}>
                  {pick.title}
                </a>
              </li>
            ))}
          </ul>
          <div className="nodeletfoot morelink">
            (<a href="/title/Page%20of%20Cool">more</a>)
          </div>
        </div>
      )}

      {creamofthecool.length > 0 && (
        <div id="creamofthecool">
          <h3 id="creamofthecool_title">
            <a href="/title/Cool%20Archive">Cream of the Cool</a>
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
        <div id="frontpage_news">
          <h2 id="frontpage_news_title">
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
