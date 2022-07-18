import React from 'react'
import VitalsPortal from './Portals/VitalsPortal'
import Vitals from './Nodelets/Vitals'

import DeveloperPortal from './Portals/DeveloperPortal'
import Developer from './Nodelets/Developer'

class E2ReactRoot extends React.Component {

  constructor(props) {
    super(props);

    this.state = {
      user: {},
      node: {},
      lastCommit: "",

      use_local_assets: 0,
      assets_location: "",
      title: "",
      lastnode_id: 0,
      node_id: 0,

      developerNodelet: {page: {}, news: {}},

      // Section display
      vit_maintenance: true,
      vit_nodeinfo: true,
      vit_list: true,
      vit_nodeutil: true,
      vit_misc: true,

      edn_util: true,
      edn_edev: true     
    };
  }

  loadExternalState() {
    let initialState = {}
    const toplevelkeys = ["user","node","developerNodelet","lastCommit"]

    toplevelkeys.forEach((key) => {
      initialState[key] = e2[key]
    })

    const nodeletSections = {"vit": ["maintenance","nodeinfo","list","nodeutil","misc"], "edn": ["util","edev"]}

    Object.keys(nodeletSections).forEach((nodelet) => {
      nodeletSections[nodelet].forEach((section) => {
        initialState[nodelet+"_"+section] = (e2.display_prefs[nodelet+"_hide"+section] == 0)
      })
    })

    this.setState(initialState)
  }

  componentDidMount() {
    this.loadExternalState()
  }

  updatePreference = async (payload) => {
    let apiEndpoint = location.protocol + '//' + location.host + '/api/preferences/set'
    let currentPreferences = {}
    fetch (apiEndpoint, {method: "post", credentials: "same-origin", mode: "same-origin", headers: {"Content-Type": "application/json"}, body: JSON.stringify(payload)})
      .then(resp => {
        if(resp.status === 200) {
          return resp.json()
        } else {
          return Promise.reject("e2error")
        }
      })
      .then(dataReceived => {
        currentPreferences = dataReceived
      })
      .catch(err => {
        if(err === "e2error") return
        console.log(err)
      })

    return currentPreferences
  } 

  toggleSection = async (event,sectionid) => {
    let setPreferenceTo = !this.state[sectionid]
    let legacyPreferenceKey = sectionid.replace(/_/g,"_hide")
    this.setState({[sectionid]: setPreferenceTo})
    return await this.updatePreference({[legacyPreferenceKey]: +!setPreferenceTo})
  }

  render() {
    return <><VitalsPortal>
        <Vitals maintenance={this.state.vit_maintenance} nodeinfo={this.state.vit_nodeinfo} list={this.state.vit_list} nodeutil={this.state.vit_nodeutil} misc={this.state.vit_misc} toggleSection={this.toggleSection} />
      </VitalsPortal>
      <DeveloperPortal>
        <Developer user={this.state.user} node={this.state.node} developerNodelet={this.state.developerNodelet} lastCommit={this.state.lastCommit} toggleSection={this.toggleSection} util={this.state.edn_util} edev={this.state.edn_edev} />
      </DeveloperPortal>
      </>
  }
}

export default E2ReactRoot;
