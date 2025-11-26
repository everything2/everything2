import React from 'react'
import LinkNode from '../LinkNode'
import NodeletContainer from '../NodeletContainer'
import WriteupEntry from '../WriteupEntry'

const NeglectedDrafts = (props) => {

  return (<NodeletContainer id={props.id}
      title="Neglected Drafts" showNodelet={props.showNodelet} nodeletIsOpen={props.nodeletIsOpen}>
  <>{
      ['editor','author'].map((type,index) => {
        return (<div key={`neglected_${type}`}><h4>{type[0].toUpperCase() + type.slice(1)} neglect</h4>        
          <ul className="infolist">
          {(props.neglectedDrafts[type].length > 0)?(
          props.neglectedDrafts[type].map((entry, idx) => {
              return (
                <WriteupEntry
                  key={`neglected_${type}_${entry.node_id}`}
                  entry={entry}
                  mode="standard"
                  metadata={<span className="days"> [{entry.days} days]</span>}
                />
              )
            })):(<p><small><em>(none)</em></small></p>)
          }
          </ul></div>
        )
      })
    }<div className="nodeletfoot"><LinkNode title="Drafts For Review" type="superdoc" /></div></>
  </NodeletContainer>)
}

export default NeglectedDrafts;
