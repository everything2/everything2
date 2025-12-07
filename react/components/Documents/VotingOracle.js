import React from 'react';

const VotingOracle = ({ data, e2 }) => {
  const {
    is_guest,
    no_votes,
    is_level_zero,
    vote_count,
    upvote_count,
    downvote_count,
    percent_of_all_votes,
    percent_upvotes,
    percent_writeups_voted
  } = data;

  // Guest users
  if (is_guest) {
    return (
      <div style={styles.container}>
        <p style={styles.oracle}>
          The Oracle requires you to identify yourself. Please log in to consult the Oracle.
        </p>
      </div>
    );
  }

  // Users who haven't voted yet
  if (no_votes) {
    return (
      <div style={styles.container}>
        <p style={styles.oracle}>
          {is_level_zero
            ? '...thou art too young yet. Come back soon.'
            : 'Thou hast grown, but are still yet a man. Prove thy judgment!'}
        </p>
      </div>
    );
  }

  return (
    <div style={styles.container}>
      <div style={styles.oracleBox}>
        <p style={styles.oracle}>
          Thou hast cast <strong>{vote_count.toLocaleString()}</strong> votes...{' '}
          <strong>{percent_of_all_votes}%</strong> of the judgements made of all time,{' '}
          across <strong>{percent_writeups_voted}%</strong> of all votable writeups.{' '}
          Of these, <strong>{percent_upvotes}%</strong> are upvotes.
        </p>
      </div>

      <div style={styles.statsGrid}>
        <div style={styles.statBox}>
          <div style={styles.statValue}>{vote_count.toLocaleString()}</div>
          <div style={styles.statLabel}>Total Votes Cast</div>
        </div>
        <div style={styles.statBox}>
          <div style={styles.statValue}>{upvote_count.toLocaleString()}</div>
          <div style={styles.statLabel}>Upvotes</div>
        </div>
        <div style={styles.statBox}>
          <div style={styles.statValue}>{downvote_count.toLocaleString()}</div>
          <div style={styles.statLabel}>Downvotes</div>
        </div>
      </div>

      <div style={styles.percentGrid}>
        <div style={styles.percentBox}>
          <div style={styles.percentValue}>{percent_of_all_votes}%</div>
          <div style={styles.percentLabel}>of all votes ever cast</div>
        </div>
        <div style={styles.percentBox}>
          <div style={styles.percentValue}>{percent_writeups_voted}%</div>
          <div style={styles.percentLabel}>of votable writeups covered</div>
        </div>
        <div style={styles.percentBox}>
          <div style={styles.percentValue}>{percent_upvotes}%</div>
          <div style={styles.percentLabel}>upvote ratio</div>
        </div>
      </div>
    </div>
  );
};

const styles = {
  container: {
    maxWidth: '800px',
    margin: '0 auto',
    padding: '20px',
    fontSize: '16px',
    lineHeight: '1.6',
    color: '#111111'
  },
  oracleBox: {
    marginBottom: '30px',
    padding: '20px',
    background: 'linear-gradient(135deg, #f8f9f9 0%, #e8eef3 100%)',
    border: '2px solid #38495e',
    borderRadius: '8px',
    textAlign: 'center'
  },
  oracle: {
    fontSize: '18px',
    fontStyle: 'italic',
    color: '#38495e',
    margin: 0
  },
  statsGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(3, 1fr)',
    gap: '15px',
    marginBottom: '20px'
  },
  statBox: {
    padding: '20px',
    background: '#ffffff',
    border: '1px solid #dee2e6',
    borderRadius: '8px',
    textAlign: 'center'
  },
  statValue: {
    fontSize: '32px',
    fontWeight: 'bold',
    color: '#4060b0',
    marginBottom: '5px'
  },
  statLabel: {
    fontSize: '14px',
    color: '#507898',
    textTransform: 'uppercase',
    letterSpacing: '0.5px'
  },
  percentGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(3, 1fr)',
    gap: '15px'
  },
  percentBox: {
    padding: '15px',
    background: '#f8f9f9',
    border: '1px solid #dee2e6',
    borderRadius: '8px',
    textAlign: 'center'
  },
  percentValue: {
    fontSize: '24px',
    fontWeight: 'bold',
    color: '#38495e',
    marginBottom: '5px'
  },
  percentLabel: {
    fontSize: '12px',
    color: '#507898'
  }
};

export default VotingOracle;
