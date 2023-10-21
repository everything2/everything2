import React from 'react'
import NewWriteupsEntry from '../NewWriteupsEntry'
import NewWriteupsFilter from '../NewWriteupsFilter'
import LinkNode from '../LinkNode'
import NodeletContainer from '../NodeletContainer'

const NewWriteups = (props) => {
  return <NodeletContainer title="New Writeups" showNodelet={props.showNodelet} nodeletIsOpen={props.nodeletIsOpen} ><div className="nodelet_content"><NewWriteupsFilter limit={props.limit} newWriteupsChange={props.newWriteupsChange} noJunkChange={props.noJunkChange} noJunk={props.noJunk} user={props.user} />
  <ul className="infolist">{
    (props.newWriteupsNodelet.length === 0)?(<em>No writeups!</em>):(
      props.newWriteupsNodelet.filter((entry) => {return !entry.is_junk || !props.noJunk }).map((entry,index) => {
        if(index < props.limit)
        {
          return <NewWriteupsEntry entry={entry} key={"nwe_"+entry.node_id} editor={props.user.editor} editorHideWriteupChange={props.editorHideWriteupChange}/>
        }
      })
    )
  }</ul><div className="nodeletfoot morelink">
  (<LinkNode type="superdoc" title="Writeups By Type" display="more" />)
  </div></div></NodeletContainer>
}

export default NewWriteups;
