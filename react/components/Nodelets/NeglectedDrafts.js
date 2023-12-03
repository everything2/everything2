import React from 'react'
import LinkNode from '../LinkNode'
import NodeletContainer from '../NodeletContainer'

const NeglectedDrafts = (props) => {

  return (<NodeletContainer title="Neglected Drafts" showNodelet={props.showNodelet} nodeletIsOpen={props.nodeletIsOpen}>
    <div className="nodelet_content">{
      ['editor','user'].map((type,index) => {
        return (<h4>{type[0].toUpperCase() + type.slice(1)} neglect</h4>)
      })
    }<div class="nodeletfoot"><LinkNode title="Drafts For Review" type="superdoc" /></div>
    </div>
  </NodeletContainer>)
}

export default NeglectedDrafts;
