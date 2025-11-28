import React from 'react'
import NodeletContainer from '../NodeletContainer'
import LinkNode from '../LinkNode'

const ForReview = (props) => {
  const { forReviewData } = props

  if (!forReviewData || !forReviewData.isEditor) {
    return null // Only show to editors
  }

  const { drafts } = forReviewData

  // If no drafts, show a message
  if (!drafts || drafts.length === 0) {
    return (
      <NodeletContainer
        id={props.id}
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

  return (
    <NodeletContainer
      id={props.id}
      title="For Review"
      showNodelet={props.showNodelet}
      nodeletIsOpen={props.nodeletIsOpen}
    >
      <table style={{ width: '100%', fontSize: '12px', borderCollapse: 'collapse' }}>
        <thead>
          <tr style={{ borderBottom: '1px solid #dee2e6' }}>
            <th style={{ textAlign: 'left', padding: '8px' }}>Draft</th>
            <th style={{ textAlign: 'center', padding: '8px' }} title="node notes">N?</th>
          </tr>
        </thead>
        <tbody>
          {drafts.map((draft, index) => {
            // Clean up latestnote (remove [user] placeholder)
            const cleanNote = draft.latestnote ? draft.latestnote.replace(/\[user\]/g, '') : ''

            return (
              <tr
                key={draft.node_id}
                style={{
                  backgroundColor: index % 2 === 0 ? '#fff' : '#f8f9fa',
                  borderBottom: '1px solid #f0f0f0'
                }}
              >
                <td style={{ padding: '8px' }}>
                  <LinkNode node_id={draft.node_id} title={draft.title} />
                  <br />
                  <small style={{ color: '#666' }}>
                    by <LinkNode node_id={draft.author_user} />
                  </small>
                </td>
                <td style={{ textAlign: 'center', padding: '8px' }}>
                  {draft.notecount > 0 ? (
                    <a
                      href={`?node_id=${draft.node_id}#nodenotes`}
                      title={`${draft.notecount} notes${cleanNote ? `; latest: ${cleanNote}` : ''}`}
                    >
                      {draft.notecount}
                    </a>
                  ) : (
                    <span>&nbsp;</span>
                  )}
                </td>
              </tr>
            )
          })}
        </tbody>
      </table>
    </NodeletContainer>
  )
}

export default ForReview
