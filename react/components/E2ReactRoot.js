import React from 'react'
import VitalsPortal from './Nodelets/VitalsPortal'
import VitalsNodelet from './Nodelets/VitalsNodelet'

class E2ReactRoot extends React.Component {

  constructor(props) {
    super(props);

    this.state = {
      guest: 0,
      use_local_assets: 0,
      assets_location: "",
      title: "",
      lastnode_id: 0,
      node_id: 0,

      // Section display
      vit_maintenance: true,
      vit_nodeinfo: true,
      vit_list: true,
      vit_nodeutil: true,
      vit_misc: true
     
    };
  }

  loadExternalState() {
    let initialState = {}
    const sections = ["maintenance","nodeinfo","list","nodeutil","misc"]

    sections.forEach((section) => {
      initialState["vit_"+section] = (e2.display_prefs["vit_hide"+section] == 0)
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
    return (<VitalsPortal>
        <VitalsNodelet maintenance={this.state.vit_maintenance} nodeinfo={this.state.vit_nodeinfo} list={this.state.vit_list} nodeutil={this.state.vit_nodeutil} misc={this.state.vit_misc} toggleSection={this.toggleSection} />
      </VitalsPortal>)
  }
}

export default E2ReactRoot;
