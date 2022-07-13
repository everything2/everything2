import React from 'react'
import './NodeletSection.css'

class NodeletSection extends React.Component {
  constructor(props) {
    super(props)
  }

  render() {
    return <div id={this.props.nodelet+"section_"+this.props.section} className="nodeletsection">
          <div className="sectionheading">[<tt> <a onClick={(event) => this.props.toggleSection(event,this.props.nodelet+"_"+this.props.section)} style={{cursor:'pointer'}} >{this.props.display ? "-":"+"}</a> </tt>] <strong>{this.props.title}</strong></div> 
          <div className={`sectioncontent ${this.props.display ? '': 'toggledoff'}`}>{this.props.children}</div>
          </div>
  }
}

export default NodeletSection;
