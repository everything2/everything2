import React from 'react'
import LinkNode from '../LinkNode'
import WriteupEntry from '../WriteupEntry'
import NodeletContainer from '../NodeletContainer'

const NewLogs = (props) => {

  return (<NodeletContainer id={props.id}
      title="New Logs" showNodelet={props.showNodelet} nodeletIsOpen={props.nodeletIsOpen}><ul className="linklist">{props.daylogLinks.map((linkinfo,i) => {
    return <li className="loglink" key={"dayloglink"+i}><LinkNode type="e2node" title={linkinfo[0]} display={linkinfo[1]} /></li>
  })}
  </ul>
  <ul className="infolist">{
    (props.newWriteups.length === 0)?(<em>No logs!</em>):(
      props.newWriteups.filter((entry) => {return entry.is_log }).map((entry,index) => {
        if(index < props.limit)
        {
          return <WriteupEntry entry={entry} key={"nl_"+entry.node_id} mode="full" />
        }
      })
    )
  }</ul>

  {/* Note that 1871573 is the "log" writeuptype */}
  <div className="nodeletfoot morelink"><LinkNode title="Writeups by Type" type="superdoc" display="more" params={{wutype: 1871573}} /></div>
  </NodeletContainer>)
}

export default NewLogs;
