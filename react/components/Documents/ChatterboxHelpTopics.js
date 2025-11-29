import React from 'react'
import LinkNode from '../LinkNode'

/**
 * Chatterbox Help Topics - List of available /help commands
 *
 * Shows all available help topics that can be accessed via /help in chatterbox
 */
const ChatterboxHelpTopics = ({ data }) => {
  const { helpuser, helptopics } = data

  // Filter out aliases (topics that just point to other topics with /help)
  const primaryTopics = Object.keys(helptopics || {})
    .filter(key => !/\/help /.test(helptopics[key]))
    .sort()

  return (
    <div className="document">
      <p>
        The chatterbox help topics are a good way for new users to learn some of the basics of E2.
        Simply type "/help TOPIC" in the chatterbox to get an automated message from{' '}
        {helpuser && <LinkNode nodeId={helpuser.node_id} title={helpuser.title} />}{' '}
        about that topic. Best results will be achieved by searching in lowercase and multi-word
        topics should use underscores rather_than_spaces. If you notice errors, or think additional
        topics should be available, contact an editor.
      </p>

      <p>
        Examples:
        <br /><tt>/help editor</tt>
        <br /><tt>/help wheel_of_surprise</tt>
        <br /><tt>/help online_only_messages</tt>
      </p>

      <h3>Currently available help topics</h3>
      <p>(not including aliases for topics listed under multiple titles)</p>

      <ol>
        {primaryTopics.map(key => (
          <li key={key}>/help {key}</li>
        ))}
      </ol>
    </div>
  )
}

export default ChatterboxHelpTopics
