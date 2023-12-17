import React from 'react'
import LinkNode from '../LinkNode'
import NodeletContainer from '../NodeletContainer'

const NeglectedDrafts = (props) => {

  return (<NodeletContainer title="Neglected Drafts" showNodelet={props.showNodelet} nodeletIsOpen={props.nodeletIsOpen} neglectedDrafts={props.neglectedDrafts}>
  {
      ['editor','author'].map((type,index) => {
        return (<><h4>{type[0].toUpperCase() + type.slice(1)} neglect</h4>        
          <ul className="infolist">
          {(props.neglectedDrafts[type].length > 0)?(
          props.neglectedDrafts[type].map((entry, idx) => {
              return (<li className="contentinfo" key={`neglected_${entry.node_id}`}><LinkNode id={entry.node_id} title={entry.title} className="title"/><cite> by <LinkNode id={entry.draft_author.id} title={entry.draft_author.title} /></cite>
                <span className="days"> [{entry.days} days]</span></li>)
            })):('<p><small><em>(none)</em></small></p>')
          }
          </ul></>
        )
      })
    }<div className="nodeletfoot" key="drafts_foot"><LinkNode title="Drafts For Review" type="superdoc" /></div>
  </NodeletContainer>)
}

export default NeglectedDrafts;
