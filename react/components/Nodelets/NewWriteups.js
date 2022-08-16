import React from 'react'
import NewWriteupsEntry from '../NewWriteupsEntry'
import NewWriteupsFilter from '../NewWriteupsFilter'
import LinkNode from '../LinkNode'

const NewWriteups = (props) => {
  return <><h2 className="nodelet_title">New Writeups</h2><div className="nodelet_content"><NewWriteupsFilter limit={props.limit} newWriteupsChange={props.newWriteupsChange} user={props.user} />
  <ul className="infolist">{
    (props.newWriteupsNodelet.length === 0)?(<em>No writeups!</em>):(
      props.newWriteupsNodelet.map((entry,index) => {
        if(index < props.limit)
        {
          return <NewWriteupsEntry entry={entry} key={"nwe_"+entry.node_id} />
        }
      })
    )
  }</ul><div className="nodeletfoot morelink">
  (<LinkNode type="superdoc" title="Writeups By Type" display="more" />)
  </div></div></>
}

export default NewWriteups;
