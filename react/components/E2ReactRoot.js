import React from 'react'
import VitalsPortal from './Portals/VitalsPortal'
import Vitals from './Nodelets/Vitals'

import DeveloperPortal from './Portals/DeveloperPortal'
import Developer from './Nodelets/Developer'

import NewWriteupsPortal from './Portals/NewWriteupsPortal'
import NewWriteups from './Nodelets/NewWriteups'

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

      newWriteupsNodelet: [],

      // Section display
      vit_maintenance: true,
      vit_nodeinfo: true,
      vit_list: true,
      vit_nodeutil: true,
      vit_misc: true,

      edn_util: true,
      edn_edev: true,

      num_newwus: 20,
      nw_nojunk: false
    };
  }

  loadExternalState() {
    let initialState = {}
    const toplevelkeys = ["user","node","developerNodelet","newWriteupsNodelet","lastCommit"]

    toplevelkeys.forEach((key) => {
      initialState[key] = e2[key]
    })

    const nodeletSections = {"vit": ["maintenance","nodeinfo","list","nodeutil","misc"], "edn": ["util","edev"]}

    Object.keys(nodeletSections).forEach((nodelet) => {
      nodeletSections[nodelet].forEach((section) => {
        initialState[nodelet+"_"+section] = (e2.display_prefs[nodelet+"_hide"+section] == 0)
      })
    })

    initialState["num_newwus"] = e2.display_prefs["num_newwus"]
    initialState["nw_nojunk"] = e2.display_prefs["nw_nojunk"]

    this.setState(initialState)
  }

  componentDidMount() {
    this.loadExternalState()
  }

  apiEndpoint = () => {
    return location.protocol + '//' + location.host + '/api'
  }

  updatePreference = async (payload) => {
    let currentPreferences = {}
    fetch (this.apiEndpoint() + '/preferences/set', {method: "post", credentials: "same-origin", mode: "same-origin", headers: {"Content-Type": "application/json"}, body: JSON.stringify(payload)})
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

  refreshNewWriteups = async () => {
    return await fetch (this.apiEndpoint() + '/newwriteups', {credentials: "same-origin", mode: "same-origin"})
      .then((resp) => {
        if(resp.status === 200) {
          return resp.json()        
        }else{
          return Promise.reject("e2error")
        }
      })
      .then((dataReceived) => {
        return dataReceived
      })
      .catch(err => {
        if(err === "e2error") return
        console.log(err)
      })
  }

  toggleSection = async (event,sectionid) => {
    let setPreferenceTo = !this.state[sectionid]
    let legacyPreferenceKey = sectionid.replace(/_/g,"_hide")
    this.setState({[sectionid]: setPreferenceTo})
    return await this.updatePreference({[legacyPreferenceKey]: +!setPreferenceTo})
  }

  newWriteupsChange = async (amount) => {
    await this.updatePreference({"num_newwus": amount})
    this.setState({"num_newwus": amount})
    return amount
  }

  noJunkChange = async (value) => {
    await this.updatePreference({"nw_nojunk": +value})
    this.setState({"nw_nojunk": value})
    return value
  }

  editorHideWriteupChange = async (nodeid,notnew) => {
    let verb = (notnew)?('hide'):('show')
    await fetch (this.apiEndpoint() + '/hidewriteups/' + nodeid + '/action/' + verb, {credentials: "same-origin", mode: "same-origin"})
      .then((resp) => {
        if(resp.status === 200) {
          return resp.json()        
        }else{
          return Promise.reject("e2error")
        }
      })
      .then((dataReceived) => {
        return dataReceived
      })
      .catch(err => {
        if(err === "e2error") return
        console.log(err)
      })
    let newWriteups = await this.refreshNewWriteups()
    this.setState({"newWriteupsNodelet": newWriteups})
    return notnew
  }

  render() {
    return <><VitalsPortal>
        <Vitals maintenance={this.state.vit_maintenance} nodeinfo={this.state.vit_nodeinfo} list={this.state.vit_list} nodeutil={this.state.vit_nodeutil} misc={this.state.vit_misc} toggleSection={this.toggleSection} />
      </VitalsPortal>
      <DeveloperPortal>
        <Developer user={this.state.user} node={this.state.node} developerNodelet={this.state.developerNodelet} lastCommit={this.state.lastCommit} toggleSection={this.toggleSection} util={this.state.edn_util} edev={this.state.edn_edev} />
      </DeveloperPortal>
      <NewWriteupsPortal>
         <NewWriteups newWriteupsNodelet={this.state.newWriteupsNodelet} limit={this.state.num_newwus} noJunk={this.state.nw_nojunk} newWriteupsChange={this.newWriteupsChange} noJunkChange={this.noJunkChange} editorHideWriteupChange={this.editorHideWriteupChange} user={this.state.user} />
      </NewWriteupsPortal>
      </>
  }
}

export default E2ReactRoot;
