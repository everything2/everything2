import React, { useState } from 'react'
import Modal from 'react-modal'
import NodeletSection from '../NodeletSection'
import { IconContext } from "react-icons"
import { FaGithubSquare,FaUsers,FaCodeBranch,FaRegFile,FaRegFileCode,FaCubes,FaExternalLinkAlt } from "react-icons/fa"
import LinkNode from '../LinkNode'
import TimeDistance from '../TimeDistance'
import NodeletContainer from '../NodeletContainer'

import './Developer.css'

const githubUrl = "https://github.com/everything2/everything2"

const Developer = (props) => {
  const [modalIsOpen, setIsOpen] = React.useState(false)
  const [devVars, setDevVars] = React.useState({})

  const openModal = () => {
    setIsOpen(true)
  }

  const closeModal = () => {
    setIsOpen(false)
  }

  const getDevVars = async () => {
    let apiEndpoint = location.protocol + '//' + location.host + '/api/developervars'
    let currentVars = {}
    fetch (apiEndpoint, {method: "get", credentials: "same-origin", mode: "same-origin"})
      .then(resp => {
        if(resp.status === 200) {
          return resp.json()
        } else {
          return Promise.reject("e2error")
        }
      })
      .then(dataReceived => {
        setDevVars(dataReceived)
        currentVars = dataReceived
      })
      .catch(err => {
        if(err === "e2error") return
        console.log(err)
      })
    return currentVars
  } 

  const afterOpenModal = async () => {
    const currentVars = await getDevVars()
  }


  return <NodeletContainer title="Everything Developer" nodeletIsOpen={props.nodeletIsOpen} showNodelet={props.showNodelet} >
    <IconContext.Provider value={{ size: "1.5em", style: { lineHeight: "inherit!important", verticalAlign: "middle" }}}>
      <div className="link-with-icon"><FaGithubSquare /> <a href={githubUrl}>GitHub</a>
      <FaCodeBranch /> <a href={githubUrl + "/commit/"+props.lastCommit}>{props.lastCommit.substr(0,7)}</a></div>
      <div className="link-with-icon"><FaUsers /> <LinkNode type="usergroup" title="edev" display="EDev Usergroup" /></div>
      <br />
      <div className="link-with-icon"><FaRegFileCode /> <LinkNode type={props.node.type} title={props.node.title} display="viewcode" params={{displaytype: "viewcode"}} /> / <LinkNode type={props.node.type} title={props.node.title} display="xmltrue" params={{displaytype: "xmltrue"}} /></div>
      <div className="link-with-icon"><FaCubes /> {"node_id: "+props.node.node_id} <small>(<TimeDistance then={props.node.createtime} />)</small></div>
      <div className="link-with-icon"><FaRegFile /> <LinkNode type="nodetype" title={props.node.type} /> (<small>by <LinkNode type="htmlpage" title={props.developerNodelet.page.title} /></small>)</div>
      <div className="link-with-icon"><FaExternalLinkAlt /> <a onClick={openModal} style={{cursor:'pointer'}}>Your $VARS</a></div>
    </IconContext.Provider>
    <br /><br />
    <NodeletSection nodelet="edn" section="edev" title="edev" display={props.edev} toggleSection={props.toggleSection}>
    <ul>
    {
      (props.developerNodelet.news !== undefined && props.developerNodelet.news.weblogs !== undefined)?(
      <>{
        props.developerNodelet.news.weblogs.map((newsitem,idx) => {
          return <li key={"edn_edev"+idx}><LinkNode id={newsitem.node_id} display={newsitem.title} /></li>
        })
      }</>):(<></>)
    }
    </ul>
    </NodeletSection>
    <NodeletSection nodelet="edn" section="util" title="util" display={props.util} toggleSection={props.toggleSection}>
    <ul>
    <li><LinkNode key="edn_util0" title="List Nodes of Type" type="superdoc" /><small> (<LinkNode title="List Nodes of Type" type="superdoc" params={{filter_user: props.user.title}} display="yours" />)</small></li>
    <li><LinkNode key="edn_util1" title="Everything Data Pages" type="superdoc" /></li>
    <li><LinkNode key="edn_util2" title="Everything Document Directory" type="superdoc" /></li>
    </ul>
    </NodeletSection>
    <Modal isOpen={modalIsOpen} ariaHideApp={false} onAfterOpen={afterOpenModal} contentLabel="Your $VARS" devVars={devVars}>
    <div><h2>Your $VARS</h2><ul>{
      Object.keys(devVars).sort().map((key,idx) => {
        return <li key={"edn_vars_key_"+idx}><tt>{key+": "+devVars[key]}</tt></li>
      })
    }</ul>
    <center><button onClick={closeModal}>Close</button></center>
    </div>
    </Modal>
  </NodeletContainer>
}

export default Developer;
