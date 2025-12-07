import React, { useState } from 'react';

const WhoIsDoingWhat = ({ data, e2 }) => {
  const {
    access_denied,
    username,
    nodes = [],
    days = 2,
    node_count = 0
  } = data;

  const [daysInput, setDaysInput] = useState(days.toString());

  // Access denied for non-admins
  if (access_denied) {
    return (
      <div style={styles.container}>
        <p style={styles.denied}>
          Curiosity killed the cat, this means YOU{' '}
          <a href={`/?node=${encodeURIComponent(username)}`}>{username}</a>
        </p>
      </div>
    );
  }

  const handleSubmit = (e) => {
    e.preventDefault();
    const form = e.target;
    form.submit();
  };

  const formatDate = (dateStr) => {
    if (!dateStr) return '';
    const date = new Date(dateStr);
    return date.toLocaleString('en-US', {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  // Group nodes by type for summary
  const typeCount = {};
  nodes.forEach(node => {
    typeCount[node.type] = (typeCount[node.type] || 0) + 1;
  });

  return (
    <div style={styles.container}>
      <form method="GET" onSubmit={handleSubmit} style={styles.form}>
        <input type="hidden" name="node_id" value={e2?.node?.node_id || ''} />
        <label style={styles.label}>
          Show nodes from the last{' '}
          <input
            type="number"
            name="days"
            value={daysInput}
            onChange={(e) => setDaysInput(e.target.value)}
            style={styles.numberInput}
            min="1"
            max="30"
          />
          {' '}days
        </label>
        <button type="submit" style={styles.button}>
          Update
        </button>
      </form>

      <div style={styles.summary}>
        <strong>{node_count}</strong> nodes created in the last <strong>{days}</strong> day{days !== 1 ? 's' : ''}
        {Object.keys(typeCount).length > 0 && (
          <span style={styles.typeSummary}>
            {' '}({Object.entries(typeCount).map(([type, count], i) => (
              <span key={type}>
                {i > 0 ? ', ' : ''}{count} {type}{count !== 1 ? 's' : ''}
              </span>
            ))})
          </span>
        )}
      </div>

      {nodes.length === 0 ? (
        <p style={styles.empty}>No nodes created in this time period.</p>
      ) : (
        <ul style={styles.list}>
          {nodes.map((node) => (
            <li key={node.node_id} style={styles.item}>
              <a href={`/?node_id=${node.node_id}`} style={styles.nodeLink}>
                {node.title}
              </a>
              <span style={styles.meta}>
                {' - '}
                <span style={styles.type}>{node.type}</span>
                {' by '}
                <a href={`/?node_id=${node.author_id}`} style={styles.authorLink}>
                  {node.author}
                </a>
                <span style={styles.time}> ({formatDate(node.createtime)})</span>
              </span>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
};

const styles = {
  container: {
    maxWidth: '900px',
    margin: '0 auto',
    padding: '20px',
    fontSize: '16px',
    lineHeight: '1.6',
    color: '#111111'
  },
  denied: {
    color: '#dc3545',
    fontStyle: 'italic',
    padding: '20px',
    background: '#fff5f5',
    border: '1px solid #dc3545',
    borderRadius: '4px'
  },
  form: {
    marginBottom: '20px',
    padding: '15px',
    background: '#f8f9f9',
    border: '1px solid #dee2e6',
    borderRadius: '4px',
    display: 'flex',
    alignItems: 'center',
    gap: '15px',
    flexWrap: 'wrap'
  },
  label: {
    fontSize: '14px',
    color: '#111111'
  },
  numberInput: {
    padding: '6px 10px',
    fontSize: '14px',
    border: '1px solid #dee2e6',
    borderRadius: '4px',
    width: '60px',
    marginLeft: '5px',
    marginRight: '5px'
  },
  button: {
    padding: '8px 16px',
    background: '#4060b0',
    color: 'white',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
    fontSize: '14px',
    fontWeight: 'bold'
  },
  summary: {
    marginBottom: '20px',
    padding: '10px 15px',
    background: '#e8eef3',
    border: '1px solid #38495e',
    borderRadius: '4px',
    fontSize: '14px'
  },
  typeSummary: {
    color: '#507898'
  },
  empty: {
    color: '#507898',
    fontStyle: 'italic',
    padding: '20px',
    textAlign: 'center'
  },
  list: {
    listStyle: 'disc',
    paddingLeft: '25px',
    margin: 0
  },
  item: {
    marginBottom: '8px',
    lineHeight: '1.5'
  },
  nodeLink: {
    color: '#4060b0',
    textDecoration: 'none',
    fontWeight: '500'
  },
  meta: {
    fontSize: '14px',
    color: '#507898'
  },
  type: {
    fontStyle: 'italic',
    color: '#38495e'
  },
  authorLink: {
    color: '#4060b0',
    textDecoration: 'none'
  },
  time: {
    fontSize: '13px',
    color: '#888888'
  }
};

export default WhoIsDoingWhat;
