import React from 'react'
import Collapsible from 'react-collapsible'

const NodeletContainer = (props) => {

  return <Collapsible triggerClassName="nodelet_title closed" triggerOpenedClassName="nodelet_title open" triggerTagName="h2" triggerStyle={{cursor: 'pointer'}} trigger={props.title} onTriggerOpening={() => { if (props.showNodelet !== undefined){props.showNodelet(props.title,true)}}} onTriggerClosing={() => {if (props.showNodelet !== undefined){props.showNodelet(props.title,false)}}} open={props.nodeletIsOpen}  transitionTime="200" >
  <div className="nodelet_content">{props.children}</div>
  </Collapsible>
}

export default NodeletContainer;
