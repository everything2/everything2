import React from 'react'

/**
 * List HTML Tags - Reference list of approved HTML tags for writeups
 *
 * Phase 4a migration from Mason template list_html_tags.mc
 * Shows: Approved HTML tags and their allowed attributes
 */
const ListHtmlTags = ({ data }) => {
  const approvedTags = data.approvedTags || {}

  // Sort tags alphabetically
  const sortedTags = Object.keys(approvedTags).sort((a, b) => a.localeCompare(b))

  return (
    <div className="list-html-tags">
      <h2 className="list-html-tags__title">Approved HTML Tags for Writeups</h2>

      <p className="list-html-tags__intro">
        The following HTML tags are approved for use in writeups. Tags marked with attributes
        show which attributes are allowed for that tag.
      </p>

      <div className="list-html-tags__grid">
        {sortedTags.map((tag) => {
          const attributes = approvedTags[tag]
          const hasAttributes = attributes !== '1'

          return (
            <div key={tag} className="list-html-tags__card">
              <code className="list-html-tags__tag-name">
                &lt;{tag}&gt;
              </code>

              {hasAttributes && (
                <div className="list-html-tags__attributes">
                  {attributes.split(',').map((attr, i) => (
                    <span key={i}>
                      {i > 0 && ', '}
                      <span className="list-html-tags__attr">{attr.trim()}</span>
                    </span>
                  ))}
                </div>
              )}
            </div>
          )
        })}
      </div>
    </div>
  )
}

export default ListHtmlTags
