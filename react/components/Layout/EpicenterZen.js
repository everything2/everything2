import React from 'react'
import LinkNode from '../LinkNode'
import LogoutLink from '../LogoutLink'

/**
 * EpicenterZen - Compact header linkbar for users without Epicenter nodelet
 *
 * Displays essential user links and stats in a compact bar at the top of the page.
 * Only shown to logged-in users who don't have the Epicenter nodelet installed.
 *
 * Styling is handled via CSS classes in basesheet (1973976.css):
 * - #epicenter_zen - container styling
 * - #epicenter_zen_info - flexbox row layout
 * - .ez-separator - separator pipe styling
 * - .ez-user-link - bold user link
 * - .ez-xp-gain - green XP gain highlight
 * - .ez-gp-gain - amber GP gain highlight
 *
 * Props:
 * - user: Current user object { node_id, title, coolsleft, votesleft, level, experience, gp, gpOptOut, etc. }
 * - epicenter: Epicenter data { userSettingsId, experienceGain, gpGain, serverTime, localTime, localTimeUse, helpPage }
 */
const EpicenterZen = ({ user, epicenter }) => {
  if (!user || user.guest) return null

  const coolsLeft = user.coolsleft || 0
  const votesLeft = user.votesleft || 0
  const helpPage = epicenter?.helpPage || 'Everything2 Help'
  const experienceGain = epicenter?.experienceGain
  const gpGain = epicenter?.gpGain
  const gpOptOut = user?.gpOptOut

  // Build vote/cool elements matching Epicenter nodelet style
  const votesAndCools = []
  if (coolsLeft > 0) {
    votesAndCools.push(
      <span key="cools">
        <strong id="chingsleft">{coolsLeft}</strong> C!{coolsLeft > 1 ? 's' : ''}
      </span>
    )
  }
  if (votesLeft > 0) {
    votesAndCools.push(
      <span key="votes">
        <strong id="votesleft">{votesLeft}</strong> vote{votesLeft > 1 ? 's' : ''}
      </span>
    )
  }

  const Separator = () => <span className="ez-separator">|</span>

  return (
    <div id="epicenter_zen">
      <div id="epicenter_zen_info">
        {/* User profile link - SEO friendly /user/{username} */}
        <LinkNode type="user" title={user.title} className="ez-user-link" />
        <Separator />

        {/* Logout */}
        <LogoutLink />
        <Separator />

        {/* Settings - SEO friendly /node/superdoc/Settings */}
        <LinkNode
          type="superdoc"
          title="Settings"
          display="Preferences"
          params={{ lastnode_id: 0 }}
        />
        <Separator />

        {/* Drafts - SEO friendly /node/superdoc/Drafts */}
        <LinkNode type="superdoc" title="Drafts" />
        <Separator />

        {/* Help - SEO friendly /node/e2node/{helpPage} */}
        <LinkNode type="e2node" title={helpPage} display="Help" />
        <Separator />

        {/* Random Node */}
        <a
          href="/?op=randomnode"
          onClick={(e) => {
            e.preventDefault()
            window.location.href = `/?op=randomnode&garbage=${Math.floor(Math.random() * 100000)}`
          }}
        >
          Random
        </a>

        {/* Vote/Cool stats - matching Epicenter format */}
        {votesAndCools.length > 0 && (
          <>
            <Separator />
            <span id="voteschingsleft">
              {votesAndCools.reduce((acc, item, i) => {
                if (i === 0) return [item]
                return [...acc, ' and ', item]
              }, [])} left
            </span>
          </>
        )}

        {/* XP gain inline */}
        {experienceGain > 0 && (
          <>
            <Separator />
            <span className="ez-xp-gain">+{experienceGain} XP!</span>
          </>
        )}

        {/* GP gain inline */}
        {!gpOptOut && gpGain > 0 && (
          <>
            <Separator />
            <span className="ez-gp-gain">+{gpGain} GP!</span>
          </>
        )}

        {/* Quick actions - SEO friendly */}
        <Separator />
        <LinkNode type="fullpage" title="chatterlight" display="chat" />
        <Separator />
        <LinkNode type="superdoc" title="message inbox" display="inbox" />
      </div>
    </div>
  )
}

export default EpicenterZen
