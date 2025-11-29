import React from 'react'
import LinkNode from '../LinkNode'

/**
 * Everything2 Elsewhere - Social media and external links
 *
 * Lists E2's presence on other platforms
 */
const Everything2Elsewhere = ({ data, user }) => {
  const { maintainer } = data
  const isGuest = user?.guest

  return (
    <div className="document">
      <ul>
        <li><a href="http://twitter.com/everything2com">New Writeups Twitter Feed</a></li>
        <li><a href="http://community.livejournal.com/everything2/profile">LiveJournal community</a></li>
        <li><a href="http://www.last.fm/group/Everything2">Last.fm group</a></li>
        <li><a href="http://www.flickr.com/groups/everything2/">Flickr group</a></li>
        <li><a href="https://www.facebook.com/Everything2com/">Facebook group</a></li>
        <li><a href="http://www.segnbora.com/e2web.html">Web Pages of Everythingians</a></li>
      </ul>
      <p>You might also like to see the <LinkNode title="Community Directory" type="document" />.</p>
      {!isGuest && maintainer && (
        <p>
          Complaints? Suggestions? Tell <LinkNode nodeId={maintainer.node_id} title={maintainer.title} /> about it.
          {/* TODO: Add message box component when available */}
        </p>
      )}
    </div>
  )
}

export default Everything2Elsewhere
