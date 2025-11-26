import React, { Suspense, lazy } from 'react'

// EAGER LOADING: Guest-default nodelets (always needed for first page load)
// These are the nodelets shown to non-logged-in users per guest_nodelets config
import SignIn from './Nodelets/SignIn'
import RecommendedReading from './Nodelets/RecommendedReading'
import NewWriteups from './Nodelets/NewWriteups'

// LAZY LOADING: User-preference nodelets (only loaded when user has them enabled)
// Code splitting creates separate bundles, reducing initial page load time
const Vitals = lazy(() => import('./Nodelets/Vitals'))
const Epicenter = lazy(() => import('./Nodelets/Epicenter'))
const Developer = lazy(() => import('./Nodelets/Developer'))
const ReadThis = lazy(() => import('./Nodelets/ReadThis'))
const NewLogs = lazy(() => import('./Nodelets/NewLogs'))
const RandomNodes = lazy(() => import('./Nodelets/RandomNodes'))
const NeglectedDrafts = lazy(() => import('./Nodelets/NeglectedDrafts'))
const QuickReference = lazy(() => import('./Nodelets/QuickReference'))
const MasterControl = lazy(() => import('./Nodelets/MasterControl'))
const Statistics = lazy(() => import('./Nodelets/Statistics'))
const Notelet = lazy(() => import('./Nodelets/Notelet'))
const Categories = lazy(() => import('./Nodelets/Categories'))
const MostWanted = lazy(() => import('./Nodelets/MostWanted'))
const RecentNodes = lazy(() => import('./Nodelets/RecentNodes'))
const FavoriteNoders = lazy(() => import('./Nodelets/FavoriteNoders'))
const PersonalLinks = lazy(() => import('./Nodelets/PersonalLinks'))
const CurrentUserPoll = lazy(() => import('./Nodelets/CurrentUserPoll'))
const UsergroupWriteups = lazy(() => import('./Nodelets/UsergroupWriteups'))
const OtherUsers = lazy(() => import('./Nodelets/OtherUsers'))
const Chatterbox = lazy(() => import('./Nodelets/Chatterbox'))
const Messages = lazy(() => import('./Nodelets/Messages'))
const Notifications = lazy(() => import('./Nodelets/Notifications'))
const ForReview = lazy(() => import('./Nodelets/ForReview'))

import { E2IdleHandler } from './E2IdleHandler'
import ErrorBoundary from './ErrorBoundary'

const E2Constants = {"defaultGuestNode": 2030780, "defaultNode": 124}

// Loading fallback for lazy-loaded nodelets
const NodeletLoadingFallback = () => (
  <div style={{ padding: '10px', textAlign: 'center', color: '#666' }}>
    <small>Loading...</small>
  </div>
)

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
      mastercontrol_show: true,
      statistics_show: true,
      categories_show: true,
      mostwanted_show: true,
      recentnodes_show: true,
      favoritenoders_show: true,
      personallinks_show: true,
      currentpoll_show: true,
      usergroupwriteups_show: true,
      otherusers_show: true,
      chatterbox_show: true,
      notelet_show: true,

      signin_show: false,

      coolnodes: [],
      staffpicks: [],
      daylogLinks: [],
      news: [],

      randomNodes: [],

      neglectedDrafts: {},

      epicenter: {},

      loginMessage: "",

      quickRefSearchTerm: "",

      // Track current room ID for chatterbox filtering
      currentRoomId: null,

      // Room name and topic for chatterbox display
      roomName: null,
      roomTopic: null
    }

    const toplevelkeys = ["user","node","developerNodelet","newWriteups","lastCommit","architecture","collapsedNodelets","coolnodes","staffpicks","daylogLinks", "news", "randomNodes","neglectedDrafts", "quickRefSearchTerm", "epicenter", "masterControl", "statistics", "categories", "currentNodeId", "bounties", "recentNodes", "favoriteWriteups", "favoriteLimit", "personalLinks", "canAddCurrent", "currentNodeTitle", "currentPoll", "usergroupData", "otherUsersData", "noteletData", "messagesData", "notificationsData", "forReviewData", "nodeletorder"]
    const managedNodelets = ["newwriteups","vitals","epicenter","everythingdeveloper","recommendedreading","readthis","newlogs","neglecteddrafts","quickreference","mastercontrol","statistics","categories","mostwanted","recentnodes","favoritenoders","personallinks","currentpoll","usergroupwriteups","otherusers","chatterbox","messages","notifications","forreview","randomnodes","notelet"]
    const urlParams = new URLSearchParams(window.location.search)

    toplevelkeys.forEach((key) => {
      initialState[key] = e2[key]
    })

    // Initialize currentRoomId from user's in_room
    if (e2.user && e2.user.in_room !== undefined) {
      initialState.currentRoomId = e2.user.in_room
    }

    // Initialize room name and topic from chatterbox data
    if (e2.chatterbox) {
      initialState.roomName = e2.chatterbox.roomName
      initialState.roomTopic = e2.chatterbox.roomTopic
    }

    initialState['randomNodesPhrase'] = this.getRandomNodesPhrase();

    const nodeletSections = {"vit": ["maintenance","nodeinfo","list","nodeutil","misc"], "edn": ["util","edev"], "rtn": ["cwu","edc","nws"], "epi": ["admins","ces"], "stat": ["personal","fun","advancement"]}

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
    // NewWriteups component now handles its own polling with activity detection
    // this.scheduleCronNewWriteups()
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
    // Ensure collapsedNodelets is always a string (may be undefined if preference was deleted)
    var currentCollapsed = this.state.collapsedNodelets || ''
    var collapsedPref = currentCollapsed.replace(replacement,'')

    // Compatibility with JQuery versions
    var e2Collapsed = e2['collapsedNodelets'] || ''
    e2['collapsedNodelets'] = e2Collapsed.replace(replacement,'')
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

  updateOtherUsersData = (data) => {
    // Update otherUsersData and extract currentRoomId for chatterbox filtering
    const newState = {}

    // Handle both cases: data is the full response object or just otherUsersData
    const otherUsersData = data.otherUsersData || data
    newState.otherUsersData = otherUsersData

    if (otherUsersData && otherUsersData.currentRoomId !== undefined) {
      newState.currentRoomId = otherUsersData.currentRoomId
    }

    // Update room name and topic if provided (from change_room or create_room API)
    if (data.room_name !== undefined) {
      newState.roomName = data.room_name
    }
    if (data.room_topic !== undefined) {
      newState.roomTopic = data.room_topic
    }

    this.setState(newState)
  }

  // Phase 3: Render individual nodelets based on name (no more Portals)
  // Maps nodelet names (lowercase with spaces) to their component JSX
  renderNodelet = (nodeletName) => {
    const nodeletComponents = {
      'vitals': () => (
        <Suspense fallback={<NodeletLoadingFallback />}>
          <Vitals
            key="vitals"
            maintenance={this.state.vit_maintenance}
            nodeinfo={this.state.vit_nodeinfo}
            list={this.state.vit_list}
            nodeutil={this.state.vit_nodeutil}
            misc={this.state.vit_misc}
            toggleSection={this.toggleSection}
            showNodelet={this.showNodelet}
            nodeletIsOpen={this.state.vitals_show}
          />
        </Suspense>
      ),
      'epicenter': () => (
        <ErrorBoundary key="epicenter">
          <Suspense fallback={<NodeletLoadingFallback />}>
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
              experienceGain={this.state.epicenter?.experienceGain}
              gpGain={this.state.epicenter?.gpGain}
              randomNodeUrl={this.state.epicenter?.randomNodeUrl}
              serverTime={this.state.epicenter?.serverTime}
              localTime={this.state.epicenter?.localTime}
              showNodelet={this.showNodelet}
              nodeletIsOpen={this.state.epicenter_show}
            />
          </Suspense>
        </ErrorBoundary>
      ),
      'everything_developer': () => (
        <Suspense fallback={<NodeletLoadingFallback />}>
          <Developer
            key="everythingdeveloper"
            user={this.state.user}
            node={this.state.node}
            developerNodelet={this.state.developerNodelet}
            lastCommit={this.state.lastCommit}
            architecture={this.state.architecture}
            toggleSection={this.toggleSection}
            util={this.state.edn_util}
            edev={this.state.edn_edev}
            showNodelet={this.showNodelet}
            nodeletIsOpen={this.state.everythingdeveloper_show}
          />
        </Suspense>
      ),
      'new_writeups': () => (
        <ErrorBoundary key="newwriteups">
          <NewWriteups
            newWriteups={this.state.newWriteups}
            limit={this.state.num_newwus}
            noJunk={this.state.nw_nojunk}
            newWriteupsChange={this.newWriteupsChange}
            noJunkChange={this.noJunkChange}
            editorHideWriteupChange={this.editorHideWriteupChange}
            user={this.state.user}
            showNodelet={this.showNodelet}
            nodeletIsOpen={this.state.newwriteups_show}
          />
        </ErrorBoundary>
      ),
      'recommended_reading': () => (
        <ErrorBoundary key="recommendedreading">
          <RecommendedReading
            coolnodes={this.state.coolnodes}
            staffpicks={this.state.staffpicks}
            showNodelet={this.showNodelet}
            nodeletIsOpen={this.state.recommendedreading_show}
          />
        </ErrorBoundary>
      ),
      'read_this': () => (
        <ErrorBoundary key="readthis">
          <Suspense fallback={<NodeletLoadingFallback />}>
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
          </Suspense>
        </ErrorBoundary>
      ),
      'new_logs': () => (
        <ErrorBoundary key="newlogs">
          <Suspense fallback={<NodeletLoadingFallback />}>
            <NewLogs
            newWriteups={this.state.newWriteups}
            daylogLinks={this.state.daylogLinks}
            showNodelet={this.showNodelet}
            nodeletIsOpen={this.state.newlogs_show}
            limit={20}
          />
          </Suspense>
        </ErrorBoundary>
      ),
      'random_nodes': () => (
        <ErrorBoundary key="randomnodes">
          <Suspense fallback={<NodeletLoadingFallback />}>
            <RandomNodes
            randomNodes={this.state.randomNodes}
            randomNodesPhrase={this.state.randomNodesPhrase}
            showNodelet={this.showNodelet}
            nodeletIsOpen={this.state.randomnodes_show}
          />
          </Suspense>
        </ErrorBoundary>
      ),
      'sign_in': () => (
        <ErrorBoundary key="signin">
          <SignIn
            nodeletIsOpen={this.state.signin_show}
            user={this.state.user}
            loginGoto={this.state.loginGoto}
            loginMessage={this.state.loginMessage}
          />
        </ErrorBoundary>
      ),
      'neglected_drafts': () => (
        <ErrorBoundary key="neglecteddrafts">
          <Suspense fallback={<NodeletLoadingFallback />}>
            <NeglectedDrafts
            showNodelet={this.showNodelet}
            nodeletIsOpen={this.state.neglecteddrafts_show}
            neglectedDrafts={this.state.neglectedDrafts}
          />
          </Suspense>
        </ErrorBoundary>
      ),
      'quick_reference': () => (
        <ErrorBoundary key="quickreference">
          <Suspense fallback={<NodeletLoadingFallback />}>
            <QuickReference
            showNodelet={this.showNodelet}
            nodeletIsOpen={this.state.quickreference_show}
            quickRefSearchTerm={this.state.quickRefSearchTerm}
          />
          </Suspense>
        </ErrorBoundary>
      ),
      'master_control': () => (
        <ErrorBoundary key="mastercontrol">
          <Suspense fallback={<NodeletLoadingFallback />}>
            <MasterControl
            isEditor={this.state.masterControl?.isEditor}
            isAdmin={this.state.masterControl?.isAdmin}
            adminSearchForm={this.state.masterControl?.adminSearchForm}
            nodeToolsetData={this.state.masterControl?.nodeToolsetData}
            nodeNotesData={this.state.masterControl?.nodeNotesData}
            currentUserId={this.state.currentUserId}
            adminSection={this.state.masterControl?.adminSection}
            ceSection={this.state.masterControl?.ceSection}
            epi_admins={this.state.epi_admins}
            epi_ces={this.state.epi_ces}
            toggleSection={this.toggleSection}
            showNodelet={this.showNodelet}
            nodeletIsOpen={this.state.mastercontrol_show}
            lastCommit={this.state.lastCommit}
          />
          </Suspense>
        </ErrorBoundary>
      ),
      'statistics': () => (
        <ErrorBoundary key="statistics">
          <Suspense fallback={<NodeletLoadingFallback />}>
            <Statistics
            statistics={this.state.statistics}
            stat_personal={this.state.stat_personal}
            stat_fun={this.state.stat_fun}
            stat_advancement={this.state.stat_advancement}
            toggleSection={this.toggleSection}
            showNodelet={this.showNodelet}
            nodeletIsOpen={this.state.statistics_show}
          />
          </Suspense>
        </ErrorBoundary>
      ),
      'categories': () => (
        <ErrorBoundary key="categories">
          <Suspense fallback={<NodeletLoadingFallback />}>
            <Categories
            categories={this.state.categories}
            currentNodeId={this.state.currentNodeId}
            showNodelet={this.showNodelet}
            nodeletIsOpen={this.state.categories_show}
          />
          </Suspense>
        </ErrorBoundary>
      ),
      'most_wanted': () => (
        <ErrorBoundary key="mostwanted">
          <Suspense fallback={<NodeletLoadingFallback />}>
            <MostWanted
            bounties={this.state.bounties}
            showNodelet={this.showNodelet}
            nodeletIsOpen={this.state.mostwanted_show}
          />
          </Suspense>
        </ErrorBoundary>
      ),
      'recent_nodes': () => (
        <ErrorBoundary key="recentnodes">
          <Suspense fallback={<NodeletLoadingFallback />}>
            <RecentNodes
            recentNodes={this.state.recentNodes}
            showNodelet={this.showNodelet}
            nodeletIsOpen={this.state.recentnodes_show}
            onClearTracks={() => this.setState({ recentNodes: [] })}
          />
          </Suspense>
        </ErrorBoundary>
      ),
      'favorite_noders': () => (
        <ErrorBoundary key="favoritenoders">
          <Suspense fallback={<NodeletLoadingFallback />}>
            <FavoriteNoders
            favoriteWriteups={this.state.favoriteWriteups}
            favoriteLimit={this.state.favoriteLimit}
            showNodelet={this.showNodelet}
            nodeletIsOpen={this.state.favoritenoders_show}
          />
          </Suspense>
        </ErrorBoundary>
      ),
      'personal_links': () => (
        <ErrorBoundary key="personallinks">
          <Suspense fallback={<NodeletLoadingFallback />}>
            <PersonalLinks
            personalLinks={this.state.personalLinks}
            canAddCurrent={this.state.canAddCurrent}
            currentNodeId={this.state.currentNodeId}
            currentNodeTitle={this.state.currentNodeTitle}
            isGuest={this.state.guest}
            showNodelet={this.showNodelet}
            nodeletIsOpen={this.state.personallinks_show}
          />
          </Suspense>
        </ErrorBoundary>
      ),
      'current_poll': () => (
        <ErrorBoundary key="currentuserpoll">
          <Suspense fallback={<NodeletLoadingFallback />}>
            <CurrentUserPoll
              currentPoll={this.state.currentPoll}
              user={this.state.user}
              showNodelet={this.showNodelet}
              nodeletIsOpen={this.state.currentpoll_show}
            />
          </Suspense>
        </ErrorBoundary>
      ),
      'usergroup_writeups': () => (
        <ErrorBoundary key="usergroupwriteups">
          <Suspense fallback={<NodeletLoadingFallback />}>
            <UsergroupWriteups
            usergroupData={this.state.usergroupData}
            showNodelet={this.showNodelet}
            nodeletIsOpen={this.state.usergroupwriteups_show}
          />
          </Suspense>
        </ErrorBoundary>
      ),
      'other_users': () => (
        <ErrorBoundary key="otherusers">
          <Suspense fallback={<NodeletLoadingFallback />}>
            <OtherUsers
            otherUsersData={this.state.otherUsersData}
            onOtherUsersDataUpdate={this.updateOtherUsersData}
            showNodelet={this.showNodelet}
            nodeletIsOpen={this.state.otherusers_show}
          />
          </Suspense>
        </ErrorBoundary>
      ),
      'chatterbox': () => (
        <ErrorBoundary key="chatterbox">
          <Suspense fallback={<NodeletLoadingFallback />}>
            <Chatterbox
            user={this.props.e2?.user}
            showNodelet={this.showNodelet}
            nodeletIsOpen={this.state.chatterbox_show}
            borged={this.props.e2?.user?.vars?.borged}
            numborged={this.props.e2?.user?.vars?.numborged}
            chatSuspended={this.props.e2?.user?.chatSuspended}
            publicChatterOff={Boolean(this.props.e2?.user?.vars?.publicchatteroff)}
            easterEggs={this.props.e2?.user?.easterEggs}
            isGuest={Boolean(this.props.e2?.user?.isGuest)}
            showMessagesInChatterbox={Boolean(this.props.e2?.chatterbox?.showMessagesInChatterbox)}
            miniMessages={this.props.e2?.chatterbox?.miniMessages}
            showHelp={this.props.e2?.user?.level < 2}
            roomTopic={this.state.roomTopic}
            roomName={this.state.roomName}
            currentRoom={this.state.currentRoomId}
            initialMessages={this.props.e2?.chatterbox?.messages}
          />
          </Suspense>
        </ErrorBoundary>
      ),
      'messages': () => (
        <ErrorBoundary key="messages">
          <Suspense fallback={<NodeletLoadingFallback />}>
            <Messages
            initialMessages={this.props.e2?.messagesData}
            showNodelet={this.showNodelet}
            nodeletIsOpen={this.state.messages_show}
          />
          </Suspense>
        </ErrorBoundary>
      ),
      'notifications': () => (
        <ErrorBoundary key="notifications">
          <Suspense fallback={<NodeletLoadingFallback />}>
            <Notifications
            notificationsData={this.props.e2?.notificationsData}
            showNodelet={this.showNodelet}
            nodeletIsOpen={this.state.notifications_show}
          />
          </Suspense>
        </ErrorBoundary>
      ),
      'for_review': () => (
        <ErrorBoundary key="forreview">
          <Suspense fallback={<NodeletLoadingFallback />}>
            <ForReview
            forReviewData={this.props.e2?.forReviewData}
            showNodelet={this.showNodelet}
            nodeletIsOpen={this.state.forreview_show}
          />
          </Suspense>
        </ErrorBoundary>
      ),
      'notelet': () => (
        <ErrorBoundary key="notelet">
          <Suspense fallback={<NodeletLoadingFallback />}>
            <Notelet
            noteletData={this.state.noteletData}
            showNodelet={this.showNodelet}
            nodeletIsOpen={this.state.notelet_show}
          />
          </Suspense>
        </ErrorBoundary>
      )
    }

    const renderFn = nodeletComponents[nodeletName]
    return renderFn ? renderFn() : null
  }

  render() {
    // Phase 3: React owns sidebar content (not the wrapper - that's in zen.mc)
    // Get nodeletorder from state (passed from backend via window.e2)
    // Filter out sign_in since it's rendered separately for guests
    const nodeletorder = (this.state.nodeletorder || []).filter(name => name !== 'sign_in')

    return <>
      <E2IdleHandler
        ref={ref => { this.idleTimer = ref }}
        timeout={1000*5*60}
      />

      {/* SignIn rendered separately for guest users (not in nodeletorder) */}
      {this.state.guest && this.renderNodelet('sign_in')}

      {/* Phase 3: Render nodelets directly (React mounts inside sidebar div) */}
      {nodeletorder.map((nodeletName) => this.renderNodelet(nodeletName))}
    </>
  }
}

export default E2ReactRoot;
