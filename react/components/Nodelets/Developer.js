import React, { useState } from 'react'
import Modal from 'react-modal'
import NodeletSection from '../NodeletSection'
import { FaGithubSquare,FaUsers,FaCodeBranch,FaRegFile,FaRegFileCode,FaCubes,FaMicrochip,FaInfoCircle,FaCode } from "react-icons/fa"
import LinkNode from '../LinkNode'
import TimeDistance from '../TimeDistance'
import NodeletContainer from '../NodeletContainer'
import SourceMapModal from '../Developer/SourceMapModal'

import './Developer.css'

const githubUrl = "https://github.com/everything2/everything2"

const Developer = (props) => {
  const [modalIsOpen, setIsOpen] = React.useState(false)
  const [devVars, setDevVars] = React.useState({})
  const [sourceMapOpen, setSourceMapOpen] = React.useState(false)

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


  return <NodeletContainer id={props.id}
      title="Everything Developer" nodeletIsOpen={props.nodeletIsOpen} showNodelet={props.showNodelet} >
    <div className="dev-nodelet__content">
      <div className="dev-nodelet__row">
        <FaGithubSquare size={12} className="dev-nodelet__icon" />
        <a href={githubUrl}>GitHub</a>
        <FaCodeBranch size={12} className="dev-nodelet__icon" style={{ marginLeft: '8px' }} />
        <a href={githubUrl + "/commit/"+props.lastCommit}>{props.lastCommit.substr(0,7)}</a>
      </div>
      <div className="dev-nodelet__row">
        <FaMicrochip size={12} className="dev-nodelet__icon" />
        <span>{props.architecture}</span>
      </div>
      <div className="dev-nodelet__row dev-nodelet__row--spaced">
        <FaUsers size={12} className="dev-nodelet__icon" />
        <LinkNode type="usergroup" title="edev" display="EDev Usergroup" />
      </div>
      <div className="dev-nodelet__row">
        <FaCubes size={12} className="dev-nodelet__icon" />
        <span>node_id: {props.node.node_id} <small>(<TimeDistance then={props.node.createtime} />)</small></span>
      </div>
      <div className="dev-nodelet__row dev-nodelet__row--spaced">
        <FaRegFile size={12} className="dev-nodelet__icon" />
        <LinkNode type="nodetype" title={props.node.type} />
      </div>
      <div className="dev-nodelet__btn-wrapper">
        <button
          onClick={() => setSourceMapOpen(true)}
          className="dev-nodelet__btn"
        >
          <FaCode size={14} />
          <span>View Source Map</span>
        </button>
      </div>
      <div className="dev-nodelet__btn-wrapper">
        <button
          onClick={openModal}
          className="dev-nodelet__btn"
        >
          <FaInfoCircle size={14} />
          <span>Your $VARS</span>
        </button>
      </div>
    </div>
    <div className="dev-nodelet__spacer">
    </div>
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
    <Modal
      isOpen={modalIsOpen}
      onRequestClose={closeModal}
      onAfterOpen={afterOpenModal}
      ariaHideApp={false}
      contentLabel="Your $VARS"
      style={{
        content: {
          top: '50%',
          left: '50%',
          right: 'auto',
          bottom: 'auto',
          marginRight: '-50%',
          transform: 'translate(-50%, -50%)',
          minWidth: '400px',
          maxWidth: '600px',
        },
      }}
    >
      <div>
        <h2 className="dev-nodelet__modal-title">
          <FaInfoCircle size={20} /> Your $VARS
        </h2>

        <div className="dev-nodelet__modal-content">
          <p className="dev-nodelet__modal-intro">
            Developer variables for your current session:
          </p>
          {Object.keys(devVars).length > 0 ? (
            <ul className="dev-nodelet__vars-list">
              {Object.keys(devVars).sort().map((key,idx) => {
                return (
                  <li key={"edn_vars_key_"+idx} className="dev-nodelet__vars-item">
                    <strong>{key}:</strong> {devVars[key]}
                  </li>
                )
              })}
            </ul>
          ) : (
            <p className="dev-nodelet__vars-loading">
              Loading variables...
            </p>
          )}
        </div>

        <div className="dev-nodelet__modal-footer">
          <button
            type="button"
            onClick={closeModal}
            className="dev-nodelet__close-btn"
          >
            Close
          </button>
        </div>
      </div>
    </Modal>
    <SourceMapModal
      isOpen={sourceMapOpen}
      onClose={() => setSourceMapOpen(false)}
      sourceMap={props.developerNodelet?.sourceMap}
      nodeTitle={props.node?.title}
    />
  </NodeletContainer>
}

export default Developer;
