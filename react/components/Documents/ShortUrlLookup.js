import React from 'react'
import LinkNode from '../LinkNode'

/**
 * ShortUrlLookup - Error page for invalid short URLs
 *
 * This component only renders when the short URL is invalid.
 * Valid short URLs are handled by the server with a 303 redirect.
 */
const ShortUrlLookup = ({ data }) => {
  if (!data || !data.shortUrlLookup) return null

  const { message, shortString } = data.shortUrlLookup

  return (
    <div className="short-url-error">
      <h2>Short URL Error</h2>
      <p>{message}</p>
      <p>
        Why not try a{' '}
        <a href="/?node_id=0" title="Random Node">
          random node
        </a>{' '}
        instead?
      </p>
    </div>
  )
}

export default ShortUrlLookup
