import React from 'react';
import ParseLinks from '../ParseLinks';

const AvailableRooms = ({ data }) => {
  const { quip, rooms = [], error } = data;

  if (error) {
    return (
      <div style={styles.container}>
        <p style={styles.error}>{error}</p>
      </div>
    );
  }

  return (
    <div style={styles.container}>
      <p style={styles.quip}>
        <ParseLinks>{quip}</ParseLinks>
      </p>
      <p style={styles.goOutside}>
        ..or you could <a href="/?node=go%20outside">go outside</a>
      </p>
      <ul style={styles.roomList}>
        {rooms.map((room) => (
          <li key={room.node_id}>
            <a href={`/?node_id=${room.node_id}`}>{room.title}</a>
          </li>
        ))}
      </ul>
    </div>
  );
};

const styles = {
  container: {
    maxWidth: '800px',
    margin: '0 auto',
    padding: '20px'
  },
  quip: {
    textAlign: 'center',
    fontSize: '16px',
    color: '#111111',
    marginBottom: '30px'
  },
  goOutside: {
    textAlign: 'right',
    fontSize: '16px',
    color: '#111111',
    marginBottom: '30px'
  },
  roomList: {
    fontSize: '16px',
    lineHeight: '1.8',
    color: '#111111',
    paddingLeft: '20px'
  },
  error: {
    padding: '20px',
    background: '#f8d7da',
    color: '#721c24',
    border: '1px solid #f5c6cb',
    borderRadius: '4px'
  }
};

export default AvailableRooms;
