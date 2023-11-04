import React from 'react'
import VitalsPortal from './Portals/VitalsPortal'
import Vitals from './Nodelets/Vitals'

import DeveloperPortal from './Portals/DeveloperPortal'
import Developer from './Nodelets/Developer'

import NewWriteupsPortal from './Portals/NewWriteupsPortal'
import NewWriteups from './Nodelets/NewWriteups'

import RecommendedReadingPortal from './Portals/RecommendedReadingPortal'
import RecommendedReading from './Nodelets/RecommendedReading'

import { E2IdleHandler } from './E2IdleHandler'

import ErrorBoundary from './ErrorBoundary'

class E2ReactRoot extends React.Component {


  constructor(props) {
    super(props)
    let initialState = {
      user: {},
      node: {},
      guest: true,
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
      nw_nojunk: false,
      collapsedNodelets: '',

      newwriteups_show: true,
      everythingdeveloper_show: true,
      vitals_show: true,
      recommendedreading_show: true,

      coolnodes: [],
      staffpicks: []
    }
    
    const toplevelkeys = ["user","node","developerNodelet","newWriteupsNodelet","lastCommit","collapsedNodelets","coolnodes","staffpicks"]
    const managedNodelets = ["newwriteups","vitals","everythingdeveloper","recommendedreading"]

    toplevelkeys.forEach((key) => {
      initialState[key] = e2[key]
    })

    const nodeletSections = {"vit": ["maintenance","nodeinfo","list","nodeutil","misc"], "edn": ["util","edev"]}

    Object.keys(nodeletSections).forEach((nodelet) => {
      nodeletSections[nodelet].forEach((section) => {
        initialState[nodelet+"_"+section] = (e2.display_prefs[nodelet+"_hide"+section] == 0)
      })
    })

    if(e2["guest"] == 0)
    {
      initialState["guest"] = false
    }

    initialState["num_newwus"] = e2.display_prefs["num_newwus"]
    initialState["nw_nojunk"] = e2.display_prefs["nw_nojunk"]

    managedNodelets.forEach((nodelet) => {
      let keyname = nodelet + "_show"
      if(initialState['collapsedNodelets'].match(nodelet+'!'))
      {
        initialState[keyname] = false
      }else{
        initialState[keyname] = true
      }
    })

    this.state = initialState

    this.idleTimer = null
    this.onPrompt = this.onPrompt.bind(this)
    this.onIdle = this.onIdle.bind(this)
    this.onAction = this.onAction.bind(this)
    this.onActive = this.onActive.bind(this)
  }

  onPrompt = () => {}
  onIdle = () => {}
  onActive = (e) => {}
  onAction = (e) => {}


  componentDidMount() {
    this.scheduleCronNewWriteups()
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

  scheduleCronNewWriteups = () => {
    setInterval(async () => {
      if(this.state.newWriteupsNodelet.length !== 0)
      {
        await this.refreshNewWriteups()
      }
    }, 60000)
  }

  refreshNewWriteups = async () => {
    let idleString = ''
    if(this.idleTimer.isIdle())
    {
      idleString = '?ajaxIdle=1'
    }

    let newWriteups = await fetch (this.apiEndpoint() + '/newwriteups'+idleString, {credentials: "same-origin", mode: "same-origin"})
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

    if(newWriteups !== undefined && Array.isArray(newWriteups) && newWriteups.length > 0)
    {
      this.setState({"newWriteupsNodelet": newWriteups})
    }
  }

  toggleSection = async (event,sectionid) => {
    let setPreferenceTo = !this.state[sectionid]
    let legacyPreferenceKey = sectionid.replace(/_/g,"_hide")
    this.setState({[sectionid]: setPreferenceTo})
    return await this.updatePreference({[legacyPreferenceKey]: +!setPreferenceTo})
  }

  showNodelet = async (nodelet, showme) => {
    let prefname = nodelet.toLowerCase()
    prefname = prefname.replace(' ','')+'!'

    var replacement = new RegExp(prefname,'g')
    var collapsedPref = this.state.collapsedNodelets.replace(replacement,'')

    // Compatibility with JQuery versions
     e2['collapsedNodelets'] = e2['collapsedNodelets'].replace(replacement,'')
     let cookies = document.cookie.split(/;\s?/).map(v => v.split('='))
    cookies.forEach((element,index) => {
      if(cookies[index][0] == 'collapsedNodelets')
      {
        cookies[index][1] = cookies[index][1].replace(replacement,'')
        if(!showme)
        {
          cookies[index][1] += prefname
        }
        document.cookie = 'collapsedNodelets='+cookies[index][1]
      }
    })

    if(!showme)
    {
      collapsedPref += prefname
      // e2['collapsedNodelets'] += prefname
    }

    this.setState({collapsedNodelets: collapsedPref})

    if(this.state.guest)
    {
      return true
    }else{
      return await this.updatePreference({'collapsedNodelets': collapsedPref})
    }
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
    await this.refreshNewWriteups()
    return notnew
  }

  render() {
    return <>
      <E2IdleHandler
        ref={ref => { this.idleTimer = ref }}
        timeout={1000*5*60}
      />
      <VitalsPortal>
        <Vitals maintenance={this.state.vit_maintenance} nodeinfo={this.state.vit_nodeinfo} list={this.state.vit_list} nodeutil={this.state.vit_nodeutil} misc={this.state.vit_misc} toggleSection={this.toggleSection} showNodelet={this.showNodelet} nodeletIsOpen={this.state.vitals_show} />
      </VitalsPortal>
      <DeveloperPortal>
        <Developer user={this.state.user} node={this.state.node} developerNodelet={this.state.developerNodelet} lastCommit={this.state.lastCommit} toggleSection={this.toggleSection} util={this.state.edn_util} edev={this.state.edn_edev} showNodelet={this.showNodelet} nodeletIsOpen={this.state.everythingdeveloper_show} />
      </DeveloperPortal>
      <NewWriteupsPortal>
        <ErrorBoundary>
         <NewWriteups newWriteupsNodelet={this.state.newWriteupsNodelet} limit={this.state.num_newwus} noJunk={this.state.nw_nojunk} newWriteupsChange={this.newWriteupsChange} noJunkChange={this.noJunkChange} editorHideWriteupChange={this.editorHideWriteupChange} user={this.state.user} showNodelet={this.showNodelet} nodeletIsOpen={this.state.newwriteups_show} />
        </ErrorBoundary>
      </NewWriteupsPortal>
      <RecommendedReadingPortal>
        <ErrorBoundary>
          <RecommendedReading coolnodes={this.state.coolnodes} staffpicks={this.state.staffpicks} showNodelet={this.showNodelet} nodeletIsOpen={this.state.recommendedreading_show} />
        </ErrorBoundary>
      </RecommendedReadingPortal>
      </>
  }
}

export default E2ReactRoot;
