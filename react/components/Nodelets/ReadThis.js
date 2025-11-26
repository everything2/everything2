import React from 'react'
import LinkNode from '../LinkNode'
import NodeletContainer from '../NodeletContainer'
import NodeletSection from '../NodeletSection'

const ReadThis = (props) => {
  return (
    <NodeletContainer
      id={props.id}
      title="ReadThis"
      showNodelet={props.showNodelet}
      nodeletIsOpen={props.nodeletIsOpen}
    >
      <NodeletSection
        nodelet="rtn"
        section="cwu"
        title="Cool Writeups"
        display={props.cwu_show}
        toggleSection={props.toggleSection}
      >
        <ul className="infolist">
          {props.coolnodes && props.coolnodes.map((coolnode, i) => (
            <li key={"rtncoolnode" + i}>
              <LinkNode
                id={coolnode.coolwriteups_id}
                title={coolnode.parentTitle}
                params={{lastnode_id: 0}}
              />
            </li>
          ))}
        </ul>
        <div className="nodeletfoot">
          (<LinkNode type="superdoc" title="Cool Archive" />)
        </div>
      </NodeletSection>

      <NodeletSection
        nodelet="rtn"
        section="edc"
        title="Editor Selections"
        display={props.edc_show}
        toggleSection={props.toggleSection}
      >
        <ul className="infolist">
          {props.staffpicks && props.staffpicks.map((staffpick, i) => (
            <li key={"rtnstaffpick" + i}>
              <LinkNode
                id={staffpick.node_id}
                display={staffpick.title}
              />
            </li>
          ))}
        </ul>
        <div className="nodeletfoot">
          (<LinkNode type="superdoc" title="Page of Cool" />)
        </div>
      </NodeletSection>

      <NodeletSection
        nodelet="rtn"
        section="nws"
        title="News"
        display={props.nws_show}
        toggleSection={props.toggleSection}
      >
        <div className="nodeletcontent">
          {props.news && props.news.length > 0 ? (
            <ul className="infolist">
              {props.news.map((newsItem, i) => (
                <li key={"rtnnews" + i}>
                  <LinkNode
                    id={newsItem.node_id}
                    display={newsItem.title}
                  />
                </li>
              ))}
            </ul>
          ) : (
            <em>No news is good news</em>
          )}
        </div>
      </NodeletSection>
    </NodeletContainer>
  )
}

export default ReadThis
