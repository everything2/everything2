import React from 'react'
import Collapsible from 'react-collapsible'

const NodeletContainer = (props) => {
  // Generate unique IDs based on nodelet id/title to avoid duplicate IDs
  // The react-collapsible library uses Date.now() which can collide
  const uniqueId = props.id || props.title?.replace(/\s+/g, '-').toLowerCase() || 'nodelet'
  const contentId = `nodelet-content-${uniqueId}`
  const triggerId = `nodelet-trigger-${uniqueId}`

  return (
    <div className="nodelet" id={props.id} data-reader-ignore="true">
      <Collapsible
        triggerClassName="nodelet_title closed"
        triggerOpenedClassName="nodelet_title open"
        triggerTagName="h2"
        triggerStyle={{cursor: 'pointer'}}
        trigger={props.title}
        contentElementId={contentId}
        triggerElementProps={{ id: triggerId }}
        onTriggerOpening={() => { if (props.showNodelet !== undefined){props.showNodelet(props.title,true)}}}
        onTriggerClosing={() => {if (props.showNodelet !== undefined){props.showNodelet(props.title,false)}}}
        open={props.nodeletIsOpen}
        transitionTime="200"
      >
        <div className="nodelet_content">{props.children}</div>
      </Collapsible>
    </div>
  )
}

export default NodeletContainer;
