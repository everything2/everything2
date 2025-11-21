import React from 'react'
import LinkNode from '../LinkNode'
import NodeletContainer from '../NodeletContainer'

const Epicenter = (props) => {
  if (props.isGuest) {
    return (
      <NodeletContainer
        title="Epicenter"
        showNodelet={props.showNodelet}
        nodeletIsOpen={props.nodeletIsOpen}
      >
        {props.borgcheck && (
          <div dangerouslySetInnerHTML={{ __html: props.borgcheck }} />
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
        <div dangerouslySetInnerHTML={{ __html: props.borgcheck }} />
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
          {props.randomNode && (
            <span dangerouslySetInnerHTML={{ __html: props.randomNode }} />
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

      {props.experienceDisplay && (
        <p id="experience">
          <span dangerouslySetInnerHTML={{ __html: props.experienceDisplay }} />
        </p>
      )}

      {!props.gpOptOut && props.gpDisplay && (
        <p id="gp">
          <span dangerouslySetInnerHTML={{ __html: props.gpDisplay }} />
        </p>
      )}

      {props.serverTimeDisplay && (
        <p id="servertime">
          <span dangerouslySetInnerHTML={{ __html: props.serverTimeDisplay }} />
        </p>
      )}
    </NodeletContainer>
  )
}

export default Epicenter
