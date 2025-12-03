import React from 'react'
import PropTypes from 'prop-types'
import UserInteractionsManager from '../UserInteractions/UserInteractionsManager'

/**
 * PitOfAbomination - Modern React replacement for the legacy Perl page
 *
 * Provides a theatrical interface for blocking users with updated terminology:
 * - "Abominate" = Block user's writeups and/or messages
 * - "Relent" = Unblock user
 */
const PitOfAbomination = ({ data }) => {
  const styles = {
    container: {
      fontFamily: 'Verdana, Arial, Helvetica, sans-serif',
      fontSize: '10pt',
      maxWidth: '900px',
      margin: '0 auto',
      padding: '20px'
    },
    header: {
      fontSize: '18pt',
      fontWeight: 'bold',
      marginBottom: '8px',
      color: '#38495e',
      textAlign: 'center'
    },
    preamble: {
      backgroundColor: '#f8f9f9',
      border: '2px solid #38495e',
      borderRadius: '6px',
      padding: '16px',
      marginBottom: '24px',
      fontSize: '11pt',
      lineHeight: '1.6',
      fontStyle: 'italic',
      color: '#111111'
    },
    helpText: {
      backgroundColor: '#fffef5',
      border: '1px solid #e8e5d0',
      borderRadius: '4px',
      padding: '12px',
      marginBottom: '20px',
      fontSize: '10pt',
      color: '#507898'
    },
    helpTitle: {
      fontWeight: 'bold',
      marginBottom: '8px',
      color: '#38495e'
    },
    helpList: {
      marginLeft: '20px',
      marginTop: '8px'
    }
  }

  return (
    <div style={styles.container}>
      <div style={styles.header}>Pit of Abomination</div>

      <div style={styles.preamble}>
        For they are an Offense in thine Eyes, and that thine Eyes might be freed from the sight
        of their Works, thou mayest abominate them here. And their feeble Screeds shall not appear
        in that List which is callèd New Writeups, nor shall they be shewn amongst the Works of
        the Worthy in the Nodes of E2. Yet still mayest thou seek them out when thy Fancy is such.
      </div>

      <div style={styles.helpText}>
        <div style={styles.helpTitle}>What does blocking do?</div>
        <ul style={styles.helpList}>
          <li><strong>Hide writeups:</strong> Prevents this user's writeups from appearing in your New Writeups list</li>
          <li><strong>Block messages:</strong> Prevents this user from sending you private messages or chat</li>
        </ul>
        <div style={{ marginTop: '12px' }}>
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
