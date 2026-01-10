import React from 'react'
import LinkNode from '../LinkNode'
import LogoutLink from '../LogoutLink'

/**
 * EpicenterZen - Compact header linkbar for users without Epicenter nodelet
 *
 * Displays essential user links and stats in a compact bar at the top of the page.
 * Only shown to logged-in users who don't have the Epicenter nodelet installed.
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

  return (
    <div id="epicenter_zen" style={styles.container}>
      <div style={styles.infoRow} id="epicenter_zen_info">
        {/* User profile link - SEO friendly /user/{username} */}
        <LinkNode type="user" title={user.title} style={styles.userLink} />
        <span style={styles.separator}>|</span>

        {/* Logout */}
        <LogoutLink style={styles.link} />
        <span style={styles.separator}>|</span>

        {/* Settings - SEO friendly /node/superdoc/Settings */}
        <LinkNode
          type="superdoc"
          title="Settings"
          display="Preferences"
          params={{ lastnode_id: 0 }}
          style={styles.link}
        />
        <span style={styles.separator}>|</span>

        {/* Drafts - SEO friendly /node/superdoc/Drafts */}
        <LinkNode type="superdoc" title="Drafts" style={styles.link} />
        <span style={styles.separator}>|</span>

        {/* Help - SEO friendly /node/e2node/{helpPage} */}
        <LinkNode type="e2node" title={helpPage} display="Help" style={styles.link} />
        <span style={styles.separator}>|</span>

        {/* Random Node */}
        <a
          href="/?op=randomnode"
          onClick={(e) => {
            e.preventDefault()
            window.location.href = `/?op=randomnode&garbage=${Math.floor(Math.random() * 100000)}`
          }}
          style={styles.link}
        >
          Random
        </a>

        {/* Vote/Cool stats - matching Epicenter format */}
        {votesAndCools.length > 0 && (
          <>
            <span style={styles.separator}>|</span>
            <span style={styles.stats} id="voteschingsleft">
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
            <span style={styles.separator}>|</span>
            <span style={styles.xpGain}>+{experienceGain} XP!</span>
          </>
        )}

        {/* GP gain inline */}
        {!gpOptOut && gpGain > 0 && (
          <>
            <span style={styles.separator}>|</span>
            <span style={styles.gpGain}>+{gpGain} GP!</span>
          </>
        )}

        {/* Quick actions - SEO friendly */}
        <span style={styles.separator}>|</span>
        <LinkNode type="fullpage" title="chatterlight" display="chat" style={styles.link} />
        <span style={styles.separator}>|</span>
        <LinkNode type="superdoc" title="message inbox" display="inbox" style={styles.link} />
      </div>
    </div>
  )
}

const styles = {
  container: {
    backgroundColor: '#2d3a4a',
    color: '#e8f4f8',
    padding: '4px 15px',
    margin: 0,
    fontSize: 12,
    lineHeight: 1.4,
    // Break out of body's 95% width and center margin to be truly flush with viewport
    width: '100vw',
    marginLeft: 'calc(-50vw + 50%)',
    boxSizing: 'border-box'
  },
  infoRow: {
    display: 'flex',
    flexWrap: 'wrap',
    alignItems: 'center',
    gap: 2
  },
  separator: {
    color: '#507898',
    margin: '0 3px'
  },
  link: {
    color: '#e8f4f8',
    textDecoration: 'none'
  },
  userLink: {
    color: '#e8f4f8',
    textDecoration: 'none',
    fontWeight: 'bold'
  },
  stats: {
    color: '#e8f4f8'
  },
  xpGain: {
    color: '#4ade80',
    fontWeight: 'bold'
  },
  gpGain: {
    color: '#fbbf24',
    fontWeight: 'bold'
  }
}

export default EpicenterZen
