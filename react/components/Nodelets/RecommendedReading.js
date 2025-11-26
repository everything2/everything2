import React from 'react'
import LinkNode from '../LinkNode'
import NodeletContainer from '../NodeletContainer'

const RecommendedReading = (props) => {
  return (<NodeletContainer id={props.id}
      title="Recommended Reading" showNodelet={props.showNodelet} nodeletIsOpen={props.nodeletIsOpen}>
  <h4><LinkNode type="e2node" title="An Introduction to Everything2" display="About Everything2" /></h4>
  <h4><LinkNode type="superdoc" title="Cool Archive" display="User Picks" /></h4>
  <ul className="infolist">{props.coolnodes.map((coolnode, i) =>
      {
        return (<li key={"rrcoolnode"+i}><LinkNode id={coolnode.coolwriteups_id} title={coolnode.parentTitle} params={{lastnode_id: 0}} /></li>)
      })
    }</ul>
  <h4><LinkNode type="superdoc" title="Page of Cool" display="Editor Picks" /></h4>
  <ul className="infolist">{props.staffpicks.map((staffpick, i) => 
      {
        return (<li key={"rrstaffpick"+i}><LinkNode id={staffpick.node_id} display={staffpick.title} /></li>)
      })
    }</ul>
  </NodeletContainer>)
}

export default RecommendedReading;
