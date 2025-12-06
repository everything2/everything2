import React from 'react';

const PermissionDenied = ({ data }) => {
  const { message } = data;

  return (
    <div style={styles.container}>
      <p style={styles.message}>{message}</p>
    </div>
  );
};

const styles = {
  container: {
    padding: '40px 20px',
    textAlign: 'center'
  },
  message: {
    fontSize: '16px',
    color: '#111111'
  }
};

export default PermissionDenied;
