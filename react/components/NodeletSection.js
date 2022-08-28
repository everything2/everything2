import React from 'react'
import './NodeletSection.css'

const NodeletSection = (props) => {
  return <div id={props.nodelet+"section_"+props.section} className="nodeletsection">
    <div className="sectionheading">[<tt> <a onClick={(event) => {props.toggleSection(event,props.nodelet+"_"+props.section)}} style={{cursor:'pointer'}} >{props.display ? "-":"+"}</a> </tt>] <strong>{props.title}</strong></div> 
    <div className={`sectioncontent ${props.display ? '': 'toggledoff'}`}>{props.children}</div>
  </div>
}

export default NodeletSection;
