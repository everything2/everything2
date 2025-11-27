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
    <div className="list-html-tags" style={{ maxWidth: '1200px', margin: '0 auto', padding: '20px' }}>
      <h2 style={{ marginBottom: '20px', color: '#333333', fontSize: '1.8em' }}>Approved HTML Tags for Writeups</h2>

      <p style={{ marginBottom: '30px', lineHeight: '1.6', color: '#111111', fontSize: '1.1em' }}>
        The following HTML tags are approved for use in writeups. Tags marked with attributes
        show which attributes are allowed for that tag.
      </p>

      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))',
        gap: '20px',
        marginBottom: '20px'
      }}>
        {sortedTags.map((tag) => {
          const attributes = approvedTags[tag]
          const hasAttributes = attributes !== '1'

          return (
            <div
              key={tag}
              style={{
                padding: '16px 20px',
                backgroundColor: '#f8f9f9',
                borderRadius: '4px',
                borderLeft: '3px solid #38495e'
              }}
            >
              <code style={{
                fontSize: '1.3em',
                fontWeight: 'bold',
                color: '#4060b0',
                fontFamily: 'monospace'
              }}>
                &lt;{tag}&gt;
              </code>

              {hasAttributes && (
                <div style={{
                  marginTop: '10px',
                  fontSize: '1em',
                  color: '#507898',
                  fontFamily: 'monospace',
                  lineHeight: '1.5'
                }}>
                  {attributes.split(',').map((attr, i) => (
                    <span key={i}>
                      {i > 0 && ', '}
                      <span style={{ color: '#3bb5c3' }}>{attr.trim()}</span>
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
