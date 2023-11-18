import React from 'react'
import LinkNode from './LinkNode'
import EditorHideWriteup from './EditorHideWriteup'

import { FaEye,FaEyeSlash } from "react-icons/fa"
import { IconContext } from "react-icons"

const NewWriteupsEntry = ({entry,editor,editorHideWriteupChange}) => {
  let parenttitle = "(broken parent)"
  let authoranchor;
  let linkparams = {}
  let authorbyline = "(broken author)"
  if(entry.parent !== undefined)
  {
    parenttitle = entry.parent.title;
  }
  if(entry.author !== undefined)
  {
    authoranchor = entry.author.title
    linkparams = {author_id: entry.author.node_id}
    authorbyline = <LinkNode type="user" title={entry.author.title} className="author" />
  }
  return <IconContext.Provider value={{style: { lineHeight: "inherit!important", verticalAlign: "middle" }}}>
    <li className={'contentinfo'+((entry.hasvoted)?(' hasvoted'):(''))} key={"writeup_"+entry.node_id}>
      <LinkNode title={parenttitle} className="title" params={linkparams} anchor={authoranchor} /><span className="type">(<LinkNode type="writeup" author={authoranchor} display={entry.writeuptype} title={parenttitle} />)</span><cite> by {authorbyline}</cite>
      {(editor)?(<EditorHideWriteup entry={entry} editorHideWriteupChange={editorHideWriteupChange} />):(<></>)}
    </li>
  </IconContext.Provider>
}

export default NewWriteupsEntry
