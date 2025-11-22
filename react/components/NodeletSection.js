import React from 'react'
import { FaChevronDown, FaChevronRight } from 'react-icons/fa'
import './NodeletSection.css'

const NodeletSection = (props) => {
  return <div id={props.nodelet+"section_"+props.section} className="nodeletsection">
    <div className="sectionheading">
      <a onClick={(event) => {props.toggleSection(event,props.nodelet+"_"+props.section)}} style={{cursor:'pointer', marginRight: '6px', display: 'inline-flex', alignItems: 'center'}} >
        {props.display ? <FaChevronDown size={12} /> : <FaChevronRight size={12} />}
      </a>
      <strong>{props.title}</strong>
    </div>
    <div className={`sectioncontent ${props.display ? '': 'toggledoff'}`}>{props.children}</div>
  </div>
}

export default NodeletSection;
