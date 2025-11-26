import React from 'react'
import LinkNode from '../LinkNode'
import NodeletContainer from '../NodeletContainer'

const RandomNodes = (props) => {

  return (<NodeletContainer id={props.id}
      title="Random Nodes" showNodelet={props.showNodelet} nodeletIsOpen={props.nodeletIsOpen}><em>{props.randomNodesPhrase}</em>
  <ul className="linklist">{
    (props.randomNodes.length === 0)?(<em>Check again later!</em>):(
      props.randomNodes.map((entry,index) => {
          return <li key={"rn_"+index}><LinkNode id={entry.node_id} display={entry.title} /></li>
      })
    )
  }</ul>

  </NodeletContainer>)
}

export default RandomNodes;
