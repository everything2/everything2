import React from 'react';

const MyRecentWriteups = ({ data }) => {
  const { is_guest, message, writeup_count, one_year_ago, user_id, username } = data;

  if (is_guest) {
    return (
      <div style={styles.container}>
        <p style={styles.guestMessage}>{message}</p>
      </div>
    );
  }

  return (
    <div style={styles.container}>
      <p style={styles.text}>
        Since one year ago, on <strong>{one_year_ago}</strong>,{' '}
        <a href={`/?node_id=${user_id}`} style={styles.link}>you</a> have published{' '}
        <strong>{writeup_count}</strong> writeup{writeup_count !== 1 ? 's' : ''}.
      </p>
    </div>
  );
};

const styles = {
  container: {
    padding: '20px',
    maxWidth: '800px',
    margin: '0 auto'
  },
  text: {
    fontSize: '16px',
    lineHeight: '1.6',
    color: '#111111'
  },
  guestMessage: {
    fontSize: '16px',
    color: '#507898',
    fontStyle: 'italic'
  },
  link: {
    color: '#4060b0',
    textDecoration: 'none'
  }
};

export default MyRecentWriteups;
