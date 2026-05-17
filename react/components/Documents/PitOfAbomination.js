import React from 'react'
import PropTypes from 'prop-types'
import UserInteractionsManager from '../UserInteractions/UserInteractionsManager'

/**
 * PitOfAbomination - Modern React replacement for the legacy Perl page
 *
 * Provides a theatrical interface for blocking users with updated terminology:
 * - "Abominate" = Block user's writeups and/or messages
 * - "Relent" = Unblock user
 * Styles in CSS: .pit-of-abomination__*
 */
const PitOfAbomination = ({ data }) => {
  return (
    <div className="pit-of-abomination">
      <div className="pit-of-abomination__header">Pit of Abomination</div>

      <div className="pit-of-abomination__preamble">
        For they are an Offense in thine Eyes, and that thine Eyes might be freed from the sight
        of their Works, thou mayest abominate them here. And their feeble Screeds shall not appear
        in that List which is callèd New Writeups, nor shall they be shewn amongst the Works of
        the Worthy in the Nodes of E2. Yet still mayest thou seek them out when thy Fancy is such.
      </div>

      <div className="pit-of-abomination__help-text">
        <div className="pit-of-abomination__help-title">What does blocking do?</div>
        <ul className="pit-of-abomination__help-list">
          <li><strong>Hide writeups:</strong> Prevents this user's writeups from appearing in your New Writeups list</li>
          <li><strong>Block messages:</strong> Prevents this user from sending you private messages or chat</li>
        </ul>
        <div className="pit-of-abomination__help-note">
          You can enable either or both options for each user. Blocked users can still see your
          content and interact with it normally - this only affects what you see.
        </div>
      </div>

      <UserInteractionsManager
        initialBlocked={data.blockedUsers || []}
        currentUser={data.currentUser}
      />
    </div>
  )
}

PitOfAbomination.propTypes = {
  data: PropTypes.shape({
    type: PropTypes.string.isRequired,
    blockedUsers: PropTypes.arrayOf(PropTypes.shape({
      node_id: PropTypes.number.isRequired,
      title: PropTypes.string.isRequired,
      type: PropTypes.string.isRequired,
      hide_writeups: PropTypes.number.isRequired,
      block_messages: PropTypes.number.isRequired
    })),
    currentUser: PropTypes.shape({
      node_id: PropTypes.oneOfType([PropTypes.number, PropTypes.string]),
      title: PropTypes.string
    })
  }).isRequired
}

export default PitOfAbomination
