import React from 'react'
import VitalsPortal from './Portals/VitalsPortal'
import Vitals from './Nodelets/Vitals'

import EpicenterPortal from './Portals/EpicenterPortal'
import Epicenter from './Nodelets/Epicenter'

import DeveloperPortal from './Portals/DeveloperPortal'
import Developer from './Nodelets/Developer'

import NewWriteupsPortal from './Portals/NewWriteupsPortal'
import NewWriteups from './Nodelets/NewWriteups'

import RecommendedReadingPortal from './Portals/RecommendedReadingPortal'
import RecommendedReading from './Nodelets/RecommendedReading'

import ReadThisPortal from './Portals/ReadThisPortal'
import ReadThis from './Nodelets/ReadThis'

import NewLogsPortal from './Portals/NewLogsPortal'
import NewLogs from './Nodelets/NewLogs'

import RandomNodesPortal from './Portals/RandomNodesPortal'
import RandomNodes from './Nodelets/RandomNodes'

import SignInPortal from './Portals/SignInPortal'
import SignIn from './Nodelets/SignIn'

import NeglectedDraftsPortal from './Portals/NeglectedDrafts'
import NeglectedDrafts from './Nodelets/NeglectedDrafts'

import QuickReference from './Nodelets/QuickReference'
import QuickReferencePortal from './Portals/QuickReferencePortal'

import { E2IdleHandler } from './E2IdleHandler'

import ErrorBoundary from './ErrorBoundary'

const E2Constants = {"defaultGuestNode": 2030780, "defaultNode": 124}

class E2ReactRoot extends React.Component {

  getRandomNodesPhrase = () => {
    let choices = ['cousin','sibling','grandpa','grandma'];
    let person = choices[Math.floor(Math.random()*choices.length)];
    let rn = Math.random();

    let phrases = [
        `Nodes your ${person} would have liked:`,
        'After stirring Everything, these nodes rose to the top:',
        'Look at this mess the Death Borg made!',
        'Just another sprinkling of '+(rn<0.5?'indeterminacy':'randomness'),
        'The '+(rn<0.5?'best':'worst')+' nodes of all time:',
        (rn<0.5?'Drink up!':'Food for thought:'),
        'Things you could have written:',
        'What you are reading:',
        'Read this. You know you want to:',
        'Nodes to '+(rn<0.5?'live by':'die for')+':',
        'Little presents from the Node Fairy:'
     ];

     return phrases[Math.floor(Math.random()*phrases.length)];
  }

  constructor(props) {
    super(props)
    let initialState = {
      user: {},
      node: {},
      guest: true,
      lastCommit: "",

      use_local_assets: 0,
      assets_location: "",

      developerNodelet: {page: {}, news: {}},

      newWriteups: [],

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
      epicenter_show: true,
      recommendedreading_show: true,
      newlogs_show: true,
      randomnodes_show: true,
      neglecteddrafts_show: true,
      quickreference_show: true,

      signin_show: false,

      coolnodes: [],
      staffpicks: [],
      daylogLinks: [],
      news: [],

      randomNodes: [],

      neglectedDrafts: {},

      epicenter: {},

      loginMessage: "",

      quickRefSearchTerm: ""
    }
    
    const toplevelkeys = ["user","node","developerNodelet","newWriteups","lastCommit","architecture","collapsedNodelets","coolnodes","staffpicks","daylogLinks", "news", "randomNodes","neglectedDrafts", "quickRefSearchTerm", "epicenter"]
    const managedNodelets = ["newwriteups","vitals","epicenter","everythingdeveloper","recommendedreading","readthis","newlogs","neglecteddrafts","quickreference"]
    const urlParams = new URLSearchParams(window.location.search)

    toplevelkeys.forEach((key) => {
      initialState[key] = e2[key]
    })

    initialState['randomNodesPhrase'] = this.getRandomNodesPhrase();

    const nodeletSections = {"vit": ["maintenance","nodeinfo","list","nodeutil","misc"], "edn": ["util","edev"], "rtn": ["cwu","edc","nws"]}

    Object.keys(nodeletSections).forEach((nodelet) => {
      nodeletSections[nodelet].forEach((section) => {
        const prefKey = nodelet+"_hide"+section;
        // Default to showing section if preference is undefined or 0
        // Hide section only if preference is explicitly set to 1
        initialState[nodelet+"_"+section] = (e2.display_prefs[prefKey] !== 1);
      })
    })

    if(e2["guest"] == 0)
    {
      initialState["guest"] = false
    }

    if(initialState["guest"])
    {
      initialState["loginGoto"] = initialState["node"]["node_id"]

      if(initialState["loginGoto"] == E2Constants["defaultGuestNode"])
      {
        initialState["loginGoto"] = E2Constants["defaultNode"]
      }

      if(urlParams.has("trylogin"))
      {
        initialState["loginMessage"] = "Login failed. Try resetting your password or contacting support"
        initialState["signin_show"] = true
      }
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
      if(this.state.newWriteups.length !== 0)
      {
        await this.refreshNewWriteups()
      }
    }, 180000)
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
      this.setState({"newWriteups": newWriteups})
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
      <EpicenterPortal>
        <ErrorBoundary>
          <Epicenter
            isGuest={this.state.user.guest}
            userName={this.state.user.title}
            votesLeft={this.state.epicenter?.votesLeft}
            cools={this.state.epicenter?.cools}
            experience={this.state.epicenter?.experience}
            gp={this.state.epicenter?.gp}
            level={this.state.epicenter?.level}
            gpOptOut={this.state.epicenter?.gpOptOut}
            localTimeUse={this.state.epicenter?.localTimeUse}
            userId={this.state.epicenter?.userId}
            userSettingsId={this.state.epicenter?.userSettingsId}
            helpPage={this.state.epicenter?.helpPage}
            borgcheck={this.state.epicenter?.borgcheck}
            experienceDisplay={this.state.epicenter?.experienceDisplay}
            gpDisplay={this.state.epicenter?.gpDisplay}
            randomNode={this.state.epicenter?.randomNode}
            serverTimeDisplay={this.state.epicenter?.serverTimeDisplay}
            showNodelet={this.showNodelet}
            nodeletIsOpen={this.state.epicenter_show}
          />
        </ErrorBoundary>
      </EpicenterPortal>
      <DeveloperPortal>
        <Developer user={this.state.user} node={this.state.node} developerNodelet={this.state.developerNodelet} lastCommit={this.state.lastCommit} architecture={this.state.architecture} toggleSection={this.toggleSection} util={this.state.edn_util} edev={this.state.edn_edev} showNodelet={this.showNodelet} nodeletIsOpen={this.state.everythingdeveloper_show} />
      </DeveloperPortal>
      <NewWriteupsPortal>
        <ErrorBoundary>
         <NewWriteups newWriteups={this.state.newWriteups} limit={this.state.num_newwus} noJunk={this.state.nw_nojunk} newWriteupsChange={this.newWriteupsChange} noJunkChange={this.noJunkChange} editorHideWriteupChange={this.editorHideWriteupChange} user={this.state.user} showNodelet={this.showNodelet} nodeletIsOpen={this.state.newwriteups_show} />
        </ErrorBoundary>
      </NewWriteupsPortal>
      <RecommendedReadingPortal>
        <ErrorBoundary>
          <RecommendedReading coolnodes={this.state.coolnodes} staffpicks={this.state.staffpicks} showNodelet={this.showNodelet} nodeletIsOpen={this.state.recommendedreading_show} />
        </ErrorBoundary>
      </RecommendedReadingPortal>
      <ReadThisPortal>
        <ErrorBoundary>
          <ReadThis
            coolnodes={this.state.coolnodes}
            staffpicks={this.state.staffpicks}
            news={this.state.news}
            cwu_show={this.state.rtn_cwu}
            edc_show={this.state.rtn_edc}
            nws_show={this.state.rtn_nws}
            toggleSection={this.toggleSection}
            showNodelet={this.showNodelet}
            nodeletIsOpen={this.state.readthis_show}
          />
        </ErrorBoundary>
      </ReadThisPortal>
      <NewLogsPortal>
        <ErrorBoundary>
          <NewLogs newWriteups={this.state.newWriteups} daylogLinks={this.state.daylogLinks} showNodelet={this.showNodelet} nodeletIsOpen={this.state.newlogs_show} limit={20} />
        </ErrorBoundary>
      </NewLogsPortal>
      <RandomNodesPortal>
        <ErrorBoundary>
          <RandomNodes randomNodes={this.state.randomNodes} randomNodesPhrase={this.state.randomNodesPhrase} showNodelet={this.showNodelet} nodeletIsOpen={this.state.randomnodes_show} />
        </ErrorBoundary>
      </RandomNodesPortal>
      <SignInPortal>
        <ErrorBoundary>
          <SignIn nodeletIsOpen={this.state.signin_show} user={this.state.user} loginGoto={this.state.loginGoto} loginMessage={this.state.loginMessage} />
        </ErrorBoundary>
      </SignInPortal>
      <NeglectedDraftsPortal>
        <ErrorBoundary>
          <NeglectedDrafts showNodelet={this.showNodelet} nodeletIsOpen={this.state.neglecteddrafts_show} neglectedDrafts={this.state.neglectedDrafts} />
        </ErrorBoundary>
      </NeglectedDraftsPortal>
      <QuickReferencePortal>
        <ErrorBoundary>
          <QuickReference showNodelet={this.showNodelet} nodeletIsOpen={this.state.quickreference_show} quickRefSearchTerm={this.state.quickRefSearchTerm} />
        </ErrorBoundary>
      </QuickReferencePortal>
      </>
  }
}

export default E2ReactRoot;
