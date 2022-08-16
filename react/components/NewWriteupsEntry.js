import React from 'react'
import LinkNode from './LinkNode'

const NewWriteupsEntry = ({entry}) => {
  return <li className="contentinfo" key={"writeup_"+entry.node_id}>
    <LinkNode title={entry.parent.title} className="title" params={{author_id: entry.author.node_id}} anchor={entry.author.title} /><span className="type">(<LinkNode type="writeup" author={entry.author.title} display={entry.writeuptype} title={entry.parent.title} />)</span><cite> by <LinkNode type="user" title={entry.author.title} className="author" /></cite>
  </li>
}

export default NewWriteupsEntry
