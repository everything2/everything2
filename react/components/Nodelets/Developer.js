import React, { useState } from 'react'
import Modal from 'react-modal'
import NodeletSection from '../NodeletSection'
import { FaGithubSquare,FaUsers,FaCodeBranch,FaRegFile,FaRegFileCode,FaCubes,FaMicrochip,FaInfoCircle } from "react-icons/fa"
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
    <div style={{ paddingLeft: '8px', paddingTop: '4px' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: '6px', marginBottom: '4px' }}>
        <FaGithubSquare size={12} style={{ color: '#666', flexShrink: 0 }} />
        <a href={githubUrl}>GitHub</a>
        <FaCodeBranch size={12} style={{ color: '#666', flexShrink: 0, marginLeft: '8px' }} />
        <a href={githubUrl + "/commit/"+props.lastCommit}>{props.lastCommit.substr(0,7)}</a>
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: '6px', marginBottom: '4px' }}>
        <FaMicrochip size={12} style={{ color: '#666', flexShrink: 0 }} />
        <span>{props.architecture}</span>
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: '6px', marginBottom: '8px' }}>
        <FaUsers size={12} style={{ color: '#666', flexShrink: 0 }} />
        <LinkNode type="usergroup" title="edev" display="EDev Usergroup" />
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: '6px', marginBottom: '4px' }}>
        <FaRegFileCode size={12} style={{ color: '#666', flexShrink: 0 }} />
        <LinkNode type={props.node.type} title={props.node.title} display="viewcode" params={{displaytype: "viewcode"}} />
        <span>/</span>
        <LinkNode type={props.node.type} title={props.node.title} display="xmltrue" params={{displaytype: "xmltrue"}} />
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: '6px', marginBottom: '4px' }}>
        <FaCubes size={12} style={{ color: '#666', flexShrink: 0 }} />
        <span>node_id: {props.node.node_id} <small>(<TimeDistance then={props.node.createtime} />)</small></span>
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: '6px', marginBottom: '4px' }}>
        <FaRegFile size={12} style={{ color: '#666', flexShrink: 0 }} />
        <span><LinkNode type="nodetype" title={props.node.type} /> (<small>by <LinkNode type="htmlpage" title={props.developerNodelet.page.title} /></small>)</span>
      </div>
    </div>
    <div style={{ marginTop: '15px' }}>
      <button
        onClick={openModal}
        style={{
          width: '100%',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          padding: '12px',
          border: '1px solid #ccc',
          borderRadius: '4px',
          backgroundColor: '#f9f9f9',
          cursor: 'pointer',
          textAlign: 'center',
          gap: '6px',
          minHeight: '70px',
          transition: 'all 0.2s ease'
        }}
        onMouseEnter={(e) => {
          e.currentTarget.style.backgroundColor = '#e9e9e9'
          e.currentTarget.style.borderColor = '#999'
        }}
        onMouseLeave={(e) => {
          e.currentTarget.style.backgroundColor = '#f9f9f9'
          e.currentTarget.style.borderColor = '#ccc'
        }}
      >
        <FaInfoCircle size={20} />
        <span>Your $VARS</span>
      </button>
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
        <h2 style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#5bc0de' }}>
          <FaInfoCircle size={20} /> Your $VARS
        </h2>

        <div style={{ margin: '20px 0', lineHeight: '1.6' }}>
          <p style={{ marginBottom: '15px' }}>
            Developer variables for your current session:
          </p>
          {Object.keys(devVars).length > 0 ? (
            <ul style={{
              listStyle: 'none',
              padding: '10px',
              backgroundColor: '#f5f5f5',
              border: '1px solid #ddd',
              borderRadius: '3px',
              maxHeight: '400px',
              overflowY: 'auto'
            }}>
              {Object.keys(devVars).sort().map((key,idx) => {
                return (
                  <li key={"edn_vars_key_"+idx} style={{
                    padding: '4px 0',
                    fontFamily: 'monospace',
                    fontSize: '0.9em'
                  }}>
                    <strong>{key}:</strong> {devVars[key]}
                  </li>
                )
              })}
            </ul>
          ) : (
            <p style={{
              padding: '20px',
              backgroundColor: '#f5f5f5',
              border: '1px solid #ddd',
              borderRadius: '3px',
              textAlign: 'center',
              color: '#666'
            }}>
              Loading variables...
            </p>
          )}
        </div>

        <div style={{ textAlign: 'right', marginTop: '20px' }}>
          <button
            type="button"
            onClick={closeModal}
            style={{
              padding: '6px 16px',
              backgroundColor: '#5bc0de',
              color: 'white',
              border: 'none',
              borderRadius: '3px',
              cursor: 'pointer',
              fontSize: '0.9em',
              display: 'inline-flex',
              alignItems: 'center',
              gap: '6px'
            }}
          >
            Close
          </button>
        </div>
      </div>
    </Modal>
  </NodeletContainer>
}

export default Developer;
