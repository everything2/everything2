import React from 'react';

const RandomNodeshells = ({ data }) => {
  const { is_guest, message, num_searched, num_found, nodeshells = [] } = data;

  if (is_guest) {
    return (
      <div style={styles.container}>
        <p style={styles.guestMessage}>{message}</p>
      </div>
    );
  }

  return (
    <div style={styles.container}>
      <div style={styles.section}>
        <p><strong>How this works:</strong></p>
        <p style={styles.description}>
          The code picks {num_searched} random possible node_ids, then checks if the node_id
          actually exists, if it is an e2node nodetype, and if it has no writeups and no firmlinks.
          Interestingly, this usually produces between 30 and 40 nodeshells with pretty good consistency.
        </p>
      </div>

      <p>
        <a href="?node=Random%20nodeshells">Generate a new list</a>
      </p>

      <p style={styles.resultText}>
        Here are <strong>{num_found}</strong> random nodeshells:
      </p>

      <ul style={styles.list}>
        {nodeshells.map((nodeshell) => (
          <li key={nodeshell.node_id}>
            <a href={`/?node_id=${nodeshell.node_id}`}>{nodeshell.title}</a>
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
  section: {
    marginBottom: '20px'
  },
  description: {
    fontSize: '16px',
    lineHeight: '1.6',
    color: '#111111',
    marginTop: '10px'
  },
  resultText: {
    fontSize: '16px',
    color: '#111111',
    marginTop: '20px',
    marginBottom: '15px'
  },
  list: {
    fontSize: '16px',
    lineHeight: '1.8',
    color: '#111111',
    paddingLeft: '20px'
  },
  guestMessage: {
    fontSize: '16px',
    color: '#507898',
    fontStyle: 'italic',
    textAlign: 'center',
    padding: '40px 20px'
  }
};

export default RandomNodeshells;
