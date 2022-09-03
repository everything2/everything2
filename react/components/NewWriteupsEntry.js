import React from 'react'
import LinkNode from './LinkNode'
import EditorHideWriteup from './EditorHideWriteup'

import { FaEye,FaEyeSlash } from "react-icons/fa"
import { IconContext } from "react-icons"

const NewWriteupsEntry = ({entry,editor,editorHideWriteupChange}) => {
  return <IconContext.Provider value={{style: { lineHeight: "inherit!important", verticalAlign: "middle" }}}>
    <li className={'contentinfo'+((entry.hasvoted)?(' hasvoted'):(''))} key={"writeup_"+entry.node_id}>
      <LinkNode title={entry.parent.title} className="title" params={{author_id: entry.author.node_id}} anchor={entry.author.title} /><span className="type">(<LinkNode type="writeup" author={entry.author.title} display={entry.writeuptype} title={entry.parent.title} />)</span><cite> by <LinkNode type="user" title={entry.author.title} className="author" /></cite>
      {(editor)?(<EditorHideWriteup entry={entry} editorHideWriteupChange={editorHideWriteupChange} />):(<></>)}
    </li>
  </IconContext.Provider>
}

export default NewWriteupsEntry
