import React from 'react'
import LinkNode from '../LinkNode'
import NodeletSection from '../NodeletSection'
import NodeletContainer from '../NodeletContainer'

const VitalsSections = [
  ["Maintenance","maintenance",[
    ["Node Title Edit","Edit These E2 Titles"],
    ["Broken Writeups","Broken Nodes"],
    ["Writeup Deletion Request","E2 Nuke Request"],
    ["Nodeshell Deletion Request","Nodeshells Marked For Destruction"],
    ["Make a bug report","E2 Bugs"],
    ["Suggest a change to E2","Suggestions for E2"]]
  ],
  ["Noding Information","nodeinfo",[
    ["Code of Conduct","Everything2 Code of Conduct"],
    ["E2 HTML Tags"],
    ["HTML Symbol Reference"],
    ["Using Unicode on E2"],
    ["Reference Desk"]]
  ],
  ["Noding Utilities","nodeutil",[
    ["Node Tracker"],
    ["Source Code Formatter","E2 Source Code Formatter"],
    ["Text Formatter"]]
  ],
  ["Lists","list",[
    ["Writeups By Type"],
    ["Everything's Most Wanted"],
    ["C! writeups","Cool Archive"],
    ["Editor Picks","Page of Cool"],
    ["Usergroup Picks"],
    ["A Year Ago Today"],
    ["Old News","News for Noders. Stuff that Matters"],
    ["Your nodeshells"],
    ["Random nodeshells"]]
  ],
  ["Miscellaneous","misc",[
    ["Everything User Poll"],
    ["The Everything2 Voting/Experience System"],
    ["Chatterlight"],
    ["E2 Gift Shop"],
    ["Everything Quote Server"],
    ["The Registries"],
    ["Do you C! what I C?"],
    ["The Recommender"]
  ]]
]

const Vitals = (props) => {
  return <NodeletContainer id={props.id}
      title="Vitals" showNodelet={props.showNodelet} nodeletIsOpen={props.nodeletIsOpen}>{VitalsSections.map((section) => {
    return <NodeletSection nodelet="vit" section={section[1]} title={section[0]} display={props[section[1]]} key={"vitsection_"+section[1]} toggleSection={props.toggleSection}><ul>
    {
      section[2].map((linkInfo,index) => {
        let trueLink = linkInfo[1]
        if(trueLink == undefined)
        {
          trueLink = linkInfo[0]
        }
        return <li key={section[1]+"_"+"i_"+index}><LinkNode title={trueLink} display={linkInfo[0]} /></li>
      })
    }
    </ul></NodeletSection>
  })}</NodeletContainer>
}

export default Vitals;
