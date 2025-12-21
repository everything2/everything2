import React from 'react'
import LinkNode from '../LinkNode'
import LogoutLink from '../LogoutLink'
import NodeletContainer from '../NodeletContainer'
import Borgcheck from '../Borgcheck'
import ExperienceGain from '../ExperienceGain'
import GPGain from '../GPGain'
import ServerTime from '../ServerTime'

const Epicenter = (props) => {
  // Use global user object instead of individual props
  const isGuest = Boolean(props.user?.guest)
  const userName = props.user?.title
  const gpOptOut = Boolean(props.user?.gpOptOut)

  if (isGuest) {
    return (
      <NodeletContainer
        id={props.id}
        title="Epicenter"
        showNodelet={props.showNodelet}
        nodeletIsOpen={props.nodeletIsOpen}
      >
        {props.borgcheck && (
          <Borgcheck
            borged={props.borgcheck.borged}
            numborged={props.borgcheck.numborged}
            currentTime={props.borgcheck.currentTime}
          />
        )}
      </NodeletContainer>
    )
  }

  // Get votes and cools from user object (set in Application.pm buildNodeInfoStructure)
  const coolsLeft = props.user?.coolsleft || 0
  const votesLeft = props.user?.votesleft || 0

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
    <NodeletContainer
      id={props.id}
      title="Epicenter"
      showNodelet={props.showNodelet}
      nodeletIsOpen={props.nodeletIsOpen}
    >
      {props.borgcheck && (
        <Borgcheck
          borged={props.borgcheck.borged}
          numborged={props.borgcheck.numborged}
          currentTime={props.borgcheck.currentTime}
        />
      )}

      <ul>
        <li>
          <LogoutLink />
        </li>
        <li title="User Settings">
          <LinkNode
            type="superdoc"
            title="Settings"
            params={{ lastnode_id: 0 }}
          />
        </li>
        <li title="Your profile">
          <LinkNode type="user" title={userName} params={{ lastnode_id: 0 }} />{' '}
          <small>
            <LinkNode
              type="user"
              title={userName}
              display="(edit)"
              params={{ displaytype: 'edit', lastnode_id: 0 }}
            />
          </small>
        </li>
        <li title="Draft, format, and organize your works in progress">
          <LinkNode type="superdoc" title="Drafts" />
        </li>
        <li title="Learn what all those numbers mean">
          <LinkNode
            type="superdoc"
            title="The Everything2 Voting/Experience System"
            display="Voting/XP System"
          />
        </li>
        <li title="View a randomly selected node">
          {props.randomNodeUrl && (
            <a href={props.randomNodeUrl}>Random Node</a>
          )}
        </li>
        <li title="Need help?">
          <LinkNode
            type="e2node"
            title={props.helpPage}
            display="Help"
          />
        </li>
      </ul>

      {votesAndCools.length > 0 && (
        <p id="voteschingsleft">
          You have {votesAndCools.reduce((acc, item, i) => {
            if (i === 0) return [item]
            return [...acc, ' and ', item]
          }, [])} left today.
        </p>
      )}

      {props.experienceGain && (
        <p id="experience">
          <ExperienceGain amount={props.experienceGain} />
        </p>
      )}

      {!gpOptOut && props.gpGain && (
        <p id="gp">
          <GPGain amount={props.gpGain} />
        </p>
      )}

      {props.serverTime && (
        <p id="servertime">
          <ServerTime
            timeString={props.serverTime}
            showLocalTime={props.localTimeUse}
            localTimeString={props.localTime}
          />
        </p>
      )}
    </NodeletContainer>
  )
}

export default Epicenter
