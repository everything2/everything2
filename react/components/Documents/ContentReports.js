import React from 'react';

const ContentReports = ({ data }) => {
  const { view, description, reports, driver, driver_title, driver_description, nodes, error } = data;

  // List view - show all reports
  if (view === 'list') {
    return (
      <div style={styles.container}>
        <p style={styles.description}>{description}</p>

        <table style={styles.table}>
          <thead>
            <tr>
              <th style={styles.th}>Driver name</th>
              <th style={{...styles.th, textAlign: 'center'}}>Failure count</th>
            </tr>
          </thead>
          <tbody>
            {reports.map((report, index) => (
              <tr key={report.driver} style={index % 2 === 0 ? styles.evenRow : styles.oddRow}>
                <td style={styles.td}>
                  <a href={`?node=Content+Reports&driver=${encodeURIComponent(report.driver)}`}>
                    {report.title}
                  </a>
                </td>
                <td style={{...styles.td, width: '150px', textAlign: 'center'}}>
                  {report.count}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    );
  }

  // Driver view - show specific report details
  if (view === 'driver') {
    if (error) {
      return (
        <div style={styles.container}>
          <p style={styles.error}>{error}</p>
          <p>
            <a href="?node=Content+Reports">Back to Content Reports</a>
          </p>
        </div>
      );
    }

    return (
      <div style={styles.container}>
        <h2 style={styles.heading}>{driver_title}</h2>
        <p style={styles.description}>{driver_description}</p>

        {nodes.length === 0 ? (
          <p>Driver <em>{driver}</em> has no failures</p>
        ) : (
          <ul style={styles.nodeList}>
            {nodes.map((node, index) => (
              <li key={node.node_id || index} style={styles.nodeItem}>
                {node.error ? (
                  <span style={styles.error}>{node.error} for id: {node.node_id}</span>
                ) : (
                  <a href={`/?node_id=${node.node_id}`}>
                    node_id: {node.node_id} title: {node.title} type: {node.type}
                  </a>
                )}
              </li>
            ))}
          </ul>
        )}

        <p>
          <a href="?node=Content+Reports">Back to Content Reports</a>
        </p>
      </div>
    );
  }

  return null;
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
  description: {
    marginBottom: '20px',
    color: '#111111'
  },
  table: {
    width: '100%',
    borderCollapse: 'collapse',
    margin: '5px',
    padding: '2px'
  },
  th: {
    padding: '8px',
    textAlign: 'left',
    borderBottom: '2px solid #dee2e6',
    backgroundColor: '#f8f9f9',
    fontWeight: 'bold'
  },
  td: {
    padding: '4px 8px',
    borderBottom: '1px solid #dee2e6'
  },
  evenRow: {
    backgroundColor: '#ffffff'
  },
  oddRow: {
    backgroundColor: '#f8f9f9'
  },
  heading: {
    fontSize: '24px',
    marginBottom: '10px',
    color: '#111111'
  },
  nodeList: {
    listStyleType: 'disc',
    paddingLeft: '20px',
    marginTop: '10px'
  },
  nodeItem: {
    marginBottom: '5px',
    lineHeight: '1.6'
  },
  error: {
    color: '#dc3545'
  }
};

export default ContentReports;
