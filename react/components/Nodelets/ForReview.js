import React from 'react'
import NodeletContainer from '../NodeletContainer'

const ForReview = (props) => {
  const { forReviewData } = props

  if (!forReviewData || !forReviewData.isEditor) {
    return null // Only show to editors
  }

  const { drafts, tableHtml } = forReviewData

  // If no drafts, show a message
  if (!drafts || drafts.length === 0) {
    return (
      <NodeletContainer
        title="For Review"
        showNodelet={props.showNodelet}
        nodeletIsOpen={props.nodeletIsOpen}
      >
        <div style={{ padding: '12px', fontSize: '12px', fontStyle: 'italic', color: '#999' }}>
          No drafts awaiting review
        </div>
      </NodeletContainer>
    )
  }

  // Use pre-rendered HTML from Perl (hybrid approach)
  // Future: Extract this into proper React components with structured data
  return (
    <NodeletContainer
      title="For Review"
      showNodelet={props.showNodelet}
      nodeletIsOpen={props.nodeletIsOpen}
    >
      <div dangerouslySetInnerHTML={{ __html: tableHtml }} />
    </NodeletContainer>
  )
}

export default ForReview
