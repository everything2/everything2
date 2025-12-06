import React from 'react';

const DatabaseLagOMeter = ({ data }) => {
  const { uptime, queries, slow_queries, slow_query_threshold, slow_per_million } = data;

  // Format numbers with commas
  const commify = (num) => {
    return num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
  };

  return (
    <div style={styles.container}>
      <div style={styles.stats}>
        <p style={styles.statLine}>
          <strong>Uptime:</strong> {uptime}
        </p>
        <p style={styles.statLine}>
          <strong>Queries:</strong> {commify(queries)}
        </p>
        <p style={styles.statLine}>
          <strong>Slow (&gt;{slow_query_threshold} sec):</strong> {commify(slow_queries)}
        </p>
        <p style={styles.statLine}>
          <strong>Slow/Million:</strong> {slow_per_million}
        </p>
      </div>

      <p style={styles.description}>
        Slow/Million Queries is a decent barometer of how much lag the Database is hitting.
        Rising=bad, falling=good.
      </p>
    </div>
  );
};

const styles = {
  container: {
    maxWidth: '600px',
    margin: '0 auto',
    padding: '20px'
  },
  stats: {
    marginBottom: '20px'
  },
  statLine: {
    fontSize: '16px',
    lineHeight: '1.8',
    color: '#111111',
    margin: '8px 0'
  },
  description: {
    fontSize: '16px',
    lineHeight: '1.6',
    color: '#111111',
    marginTop: '20px',
    padding: '15px',
    background: '#f8f9f9',
    borderRadius: '4px'
  }
};

export default DatabaseLagOMeter;
