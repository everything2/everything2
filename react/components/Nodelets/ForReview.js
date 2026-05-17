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
        <div className="for-review__empty">
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
      <table className="for-review__table">
        <thead>
          <tr className="for-review__header-row">
            <th className="for-review__th">Draft</th>
            <th className="for-review__th for-review__th--center" title="node notes">N?</th>
          </tr>
        </thead>
        <tbody>
          {drafts.map((draft, index) => {
            // Clean up latestnote (remove [user] placeholder)
            const cleanNote = draft.latestnote ? draft.latestnote.replace(/\[user\]/g, '') : ''

            return (
              <tr
                key={draft.node_id}
                className={`for-review__row ${index % 2 === 0 ? 'for-review__row--even' : 'for-review__row--odd'}`}
              >
                <td className="for-review__td">
                  <LinkNode node_id={draft.node_id} title={draft.title} />
                  <br />
                  <small className="for-review__author">
                    by <LinkNode node_id={draft.author_user} />
                  </small>
                </td>
                <td className="for-review__td for-review__td--center">
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
