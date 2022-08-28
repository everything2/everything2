import React from 'react'

import './EditorHideWriteup.css'
import { FaEye,FaEyeSlash } from "react-icons/fa"
import { IconContext } from "react-icons"

const EditorHideWriteup = ({entry,editorHideWriteupChange}) => {
  return <IconContext.Provider value={{style: { lineHeight: "inherit!important", verticalAlign: "middle" }}}>
      <div className="editorhidelink" aria-label="Toggle writeup visibility" onClick={() => editorHideWriteupChange(entry.node_id,!entry.notnew)}>{(entry.notnew)?(<>{'('}<FaEyeSlash />{')'}</>):(<>{'('}<FaEye />{')'}</>)}</div></IconContext.Provider>
}

export default EditorHideWriteup
