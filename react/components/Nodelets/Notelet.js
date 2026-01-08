import React from 'react'
import NodeletContainer from '../NodeletContainer'
import LinkNode from '../LinkNode'
import ParseLinks from '../ParseLinks'

const Notelet = (props) => {
  if (!props.noteletData) {
    return (
      <NodeletContainer
        id={props.id}
      title="Notelet"
        showNodelet={props.showNodelet}
        nodeletIsOpen={props.nodeletIsOpen}
      >
        <p style={{ padding: '8px', fontSize: '12px', fontStyle: 'italic' }}>
          No notelet data available
        </p>
      </NodeletContainer>
    )
  }

  const { isLocked, hasContent, content, isGuest } = props.noteletData

  return (
    <NodeletContainer
      id={props.id}
      title="Notelet"
      showNodelet={props.showNodelet}
      nodeletIsOpen={props.nodeletIsOpen}
    >
      {isLocked ? (
        <p style={{ padding: '8px', fontSize: '12px' }}>
          Sorry, your Notelet is currently locked, probably because an administrator is working with your account. It should soon be back to normal.
        </p>
      ) : (
        <>
          {!hasContent ? (
            <div style={{ padding: '8px', fontSize: '12px' }}>
              <p>You currently have no text set for your personal nodelet. You can edit it at{' '}
                <LinkNode title="Notelet Editor" nodeType="superdoc" /> or manage nodelets in{' '}
                <LinkNode title="Settings" nodeType="superdoc" />.
              </p>
            </div>
          ) : (
            <div style={{ padding: '8px', fontSize: '12px' }}>
              <ParseLinks>{content}</ParseLinks>
            </div>
          )}
          <div className="nodeletfoot">
            (<LinkNode title="Notelet editor" nodeType="superdoc" display="edit" />)
          </div>
        </>
      )}
    </NodeletContainer>
  )
}

export default Notelet
