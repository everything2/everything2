import React from 'react'
import LinkNode from '../LinkNode'
import NodeletContainer from '../NodeletContainer'
import Borgcheck from '../Borgcheck'
import ExperienceGain from '../ExperienceGain'
import GPGain from '../GPGain'
import ServerTime from '../ServerTime'

const Epicenter = (props) => {
  if (props.isGuest) {
    return (
      <NodeletContainer
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

  const votesAndCools = []
  if (props.cools) {
    votesAndCools.push(
      <span key="cools">
        <strong id="chingsleft">{props.cools}</strong> C!{props.cools > 1 ? 's' : ''}
      </span>
    )
  }
  if (props.votesLeft) {
    votesAndCools.push(
      <span key="votes">
        <strong id="votesleft">{props.votesLeft}</strong> vote{props.votesLeft > 1 ? 's' : ''}
      </span>
    )
  }

  return (
    <NodeletContainer
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
          <LinkNode type="superdoc" title="login" display="Log Out" params={{ op: 'logout' }} />
        </li>
        <li title="User Settings">
          <LinkNode
            type="superdoc"
            title="Settings"
            params={{ lastnode_id: 0 }}
          />
        </li>
        <li title="Your profile">
          <LinkNode type="user" title={props.userName} params={{ lastnode_id: 0 }} />{' '}
          <small>
            <LinkNode
              type="user"
              title={props.userName}
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

      {!props.gpOptOut && props.gpGain && (
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
