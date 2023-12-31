import React from 'react'
import LinkNode from '../LinkNode'
import NodeletContainer from '../NodeletContainer'

const NeglectedDrafts = (props) => {

  return (<NodeletContainer title="Neglected Drafts" showNodelet={props.showNodelet} nodeletIsOpen={props.nodeletIsOpen}>
  <>{
      ['editor','author'].map((type,index) => {
        return (<div key={`neglected_${type}`}><h4>{type[0].toUpperCase() + type.slice(1)} neglect</h4>        
          <ul className="infolist">
          {(props.neglectedDrafts[type].length > 0)?(
          props.neglectedDrafts[type].map((entry, idx) => {
              return (<li key={`neglected_${type}_${entry.node_id}`} className="contentinfo"><LinkNode id={entry.node_id} title={entry.title} className="title"/><cite> by <LinkNode id={entry.author.id} title={entry.author.title} /></cite>
                <span className="days"> [{entry.days} days]</span></li>)
            })):(<p><small><em>(none)</em></small></p>)
          }
          </ul></div>
        )
      })
    }<div className="nodeletfoot"><LinkNode title="Drafts For Review" type="superdoc" /></div></>
  </NodeletContainer>)
}

export default NeglectedDrafts;
