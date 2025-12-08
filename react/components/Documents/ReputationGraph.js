import React, { useState, useEffect } from 'react';

/**
 * ReputationGraph - Monthly reputation visualization for writeups
 * Supports both horizontal (simple bar) and vertical (table) layouts
 */
const ReputationGraph = ({ data }) => {
  const {
    error,
    writeup,
    author,
    can_view,
    is_admin,
    layout = 'vertical' // 'horizontal' or 'vertical'
  } = data;

  const [graphData, setGraphData] = useState(null);
  const [loading, setLoading] = useState(false);
  const [fetchError, setFetchError] = useState(null);

  // Fetch vote data when we have a valid writeup
  useEffect(() => {
    if (!writeup || !can_view) return;

    const fetchVoteData = async () => {
      setLoading(true);
      setFetchError(null);

      try {
        const response = await fetch(`/api/reputation/votes?writeup_id=${writeup.node_id}`);
        const result = await response.json();

        if (result.success) {
          setGraphData(result.data);
        } else {
          setFetchError(result.error || 'Failed to fetch vote data');
        }
      } catch (err) {
        setFetchError('Network error: ' + err.message);
      } finally {
        setLoading(false);
      }
    };

    fetchVoteData();
  }, [writeup, can_view]);

  // Error state
  if (error) {
    return (
      <div style={styles.container}>
        <div style={styles.error}>
          <p>{error}</p>
        </div>
      </div>
    );
  }

  // Access denied
  if (!can_view) {
    return (
      <div style={styles.container}>
        <div style={styles.accessDenied}>
          <p>You haven't voted on that writeup, so you are not allowed to see its reputation.</p>
          <p>Try clicking on the "Rep Graph" link from a writeup you have already voted on.</p>
        </div>
      </div>
    );
  }

  // Loading state
  if (loading) {
    return (
      <div style={styles.container}>
        <p style={styles.loading}>Loading reputation data...</p>
      </div>
    );
  }

  // Fetch error
  if (fetchError) {
    return (
      <div style={styles.container}>
        <div style={styles.error}>
          <p>{fetchError}</p>
        </div>
      </div>
    );
  }

  // Waiting for data
  if (!graphData) {
    return (
      <div style={styles.container}>
        <p style={styles.loading}>Loading...</p>
      </div>
    );
  }

  const isHorizontal = layout === 'horizontal';

  return (
    <div style={styles.container}>
      <p style={styles.intro}>
        You are viewing the monthly reputation graph for the following writeup:<br />
        <a href={`/?node_id=${writeup.node_id}`} style={styles.link}>{writeup.title}</a>
        {' by '}
        <a href={`/?node_id=${author.node_id}`} style={styles.link}>{author.title}</a>
      </p>

      <p style={styles.hint}>
        {isHorizontal
          ? 'Hover your mouse over any of the bars on the graph to see the date and reputation for each month.'
          : 'Monthly breakdown of upvotes and downvotes over time.'}
      </p>

      {isHorizontal ? (
        <HorizontalGraph data={graphData} />
      ) : (
        <VerticalGraph data={graphData} />
      )}

      {is_admin && (
        <p style={styles.adminNote}>
          NOTE: Admins can view the graph of any writeup by simply appending "&id=&lt;writeup_id&gt;" to the end of the URL
        </p>
      )}
    </div>
  );
};

/**
 * HorizontalGraph - Simple bar chart showing cumulative reputation per month
 */
const HorizontalGraph = ({ data }) => {
  const { months } = data;

  if (!months || months.length === 0) {
    return <p style={styles.empty}>No vote data available.</p>;
  }

  // Find max values for scaling
  const maxPos = Math.max(...months.map(m => Math.max(0, m.reputation)), 1);
  const maxNeg = Math.max(...months.map(m => Math.max(0, -m.reputation)), 1);
  const scale = Math.min(1, 100 / Math.max(maxPos, maxNeg));

  return (
    <div style={styles.horizontalContainer}>
      <table style={styles.horizontalTable}>
        <tbody>
          {/* Positive bars row */}
          <tr style={styles.positiveRow}>
            {months.map((month, idx) => (
              <td
                key={`pos-${idx}`}
                style={styles.horizontalCell}
                title={`${month.label} - Rep: ${month.reputation}`}
              >
                {month.reputation >= 0 && (
                  <div
                    style={{
                      ...styles.posBar,
                      height: `${Math.max(1, month.reputation * scale)}px`
                    }}
                  />
                )}
              </td>
            ))}
          </tr>
          {/* Negative bars row */}
          <tr style={styles.negativeRow}>
            {months.map((month, idx) => (
              <td
                key={`neg-${idx}`}
                style={styles.horizontalCell}
                title={`${month.label} - Rep: ${month.reputation}`}
              >
                {month.reputation < 0 && (
                  <div
                    style={{
                      ...styles.negBar,
                      height: `${Math.max(1, -month.reputation * scale)}px`
                    }}
                  />
                )}
              </td>
            ))}
          </tr>
          {/* Year labels row */}
          <tr style={styles.labelRow}>
            {months.map((month, idx) => (
              <td key={`label-${idx}`} style={styles.labelCell}>
                {month.is_january ? '|' : ''}
              </td>
            ))}
          </tr>
        </tbody>
      </table>
    </div>
  );
};

/**
 * VerticalGraph - Table showing upvotes, downvotes, and reputation per month
 */
const VerticalGraph = ({ data }) => {
  const { months } = data;

  if (!months || months.length === 0) {
    return <p style={styles.empty}>No vote data available.</p>;
  }

  // Find max values for scaling bars
  const maxUp = Math.max(...months.map(m => m.upvotes), 1);
  const maxDown = Math.max(...months.map(m => Math.abs(m.downvotes)), 1);
  const scale = Math.min(1, 100 / Math.max(maxUp, maxDown));

  return (
    <div style={styles.verticalContainer}>
      <table style={styles.verticalTable}>
        <thead>
          <tr>
            <th style={styles.th}>Date</th>
            <th style={styles.th} colSpan={2}>Downvotes</th>
            <th style={styles.th} colSpan={2}>Upvotes</th>
            <th style={styles.th}>Reputation</th>
          </tr>
        </thead>
        <tbody>
          {months.map((month, idx) => (
            <tr key={idx}>
              <td style={styles.dateCell}>
                {month.is_january ? <strong>{month.label}</strong> : month.label}
              </td>
              <td style={styles.downvoteLabel}>{month.downvotes}</td>
              <td style={styles.downvoteGraph}>
                {month.downvotes < 0 && (
                  <span
                    style={{
                      ...styles.negativeBar,
                      width: `${Math.abs(month.downvotes) * scale}px`
                    }}
                  />
                )}
              </td>
              <td style={styles.upvoteGraph}>
                {month.upvotes > 0 && (
                  <span
                    style={{
                      ...styles.positiveBar,
                      width: `${month.upvotes * scale}px`
                    }}
                  />
                )}
              </td>
              <td style={styles.upvoteLabel}>+{month.upvotes}</td>
              <td style={styles.reputationLabel}>{month.reputation}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
};

const styles = {
  container: {
    maxWidth: '900px',
    margin: '0 auto',
    padding: '20px'
  },
  intro: {
    marginBottom: '16px',
    color: '#38495e'
  },
  link: {
    color: '#4060b0',
    textDecoration: 'none'
  },
  hint: {
    textAlign: 'center',
    fontSize: '13px',
    color: '#507898',
    marginBottom: '20px'
  },
  loading: {
    textAlign: 'center',
    padding: '40px',
    color: '#507898'
  },
  error: {
    padding: '20px',
    background: '#f8d7da',
    color: '#721c24',
    border: '1px solid #f5c6cb',
    borderRadius: '4px'
  },
  accessDenied: {
    padding: '20px',
    background: '#fff3cd',
    color: '#856404',
    border: '1px solid #ffc107',
    borderRadius: '4px',
    textAlign: 'center'
  },
  empty: {
    textAlign: 'center',
    padding: '40px',
    color: '#6c757d',
    background: '#f8f9f9',
    borderRadius: '4px'
  },
  adminNote: {
    textAlign: 'center',
    fontSize: '13px',
    color: '#507898',
    marginTop: '20px',
    fontStyle: 'italic'
  },

  // Horizontal graph styles
  horizontalContainer: {
    overflowX: 'auto',
    textAlign: 'center'
  },
  horizontalTable: {
    margin: '0 auto',
    borderCollapse: 'collapse',
    borderSpacing: '1px'
  },
  horizontalCell: {
    width: '4px',
    padding: '0 1px',
    verticalAlign: 'bottom'
  },
  positiveRow: {},
  negativeRow: {},
  labelRow: {
    fontWeight: 'bold',
    fontSize: '11px'
  },
  labelCell: {
    textAlign: 'center',
    color: '#507898'
  },
  posBar: {
    width: '4px',
    backgroundColor: '#0c0',
    borderTop: '2px solid #5a5',
    borderLeft: '2px solid #5a5',
    borderBottom: '2px solid #050',
    borderRight: '2px solid #050'
  },
  negBar: {
    width: '4px',
    backgroundColor: '#f00',
    borderTop: '2px solid #f88',
    borderLeft: '2px solid #f88',
    borderBottom: '2px solid #800',
    borderRight: '2px solid #800'
  },

  // Vertical graph styles
  verticalContainer: {
    overflowX: 'auto'
  },
  verticalTable: {
    width: '100%',
    borderCollapse: 'collapse',
    fontSize: '13px',
    margin: '0 auto'
  },
  th: {
    padding: '8px 12px',
    fontWeight: '600',
    color: '#38495e',
    background: '#f8f9f9',
    borderBottom: '2px solid #dee2e6',
    textAlign: 'left'
  },
  dateCell: {
    padding: '6px 20px 6px 8px',
    textAlign: 'right',
    whiteSpace: 'nowrap'
  },
  downvoteLabel: {
    textAlign: 'right',
    padding: '6px 4px',
    color: '#c00'
  },
  downvoteGraph: {
    textAlign: 'right',
    borderRight: '1px dotted #ccc',
    padding: '6px 0'
  },
  upvoteGraph: {
    textAlign: 'left',
    padding: '6px 0'
  },
  upvoteLabel: {
    textAlign: 'left',
    padding: '6px 4px',
    color: '#0a0'
  },
  reputationLabel: {
    textAlign: 'right',
    padding: '6px 8px',
    fontWeight: 'bold'
  },
  negativeBar: {
    display: 'inline-block',
    height: '12px',
    backgroundColor: '#f00',
    borderTop: '2px solid #f88',
    borderLeft: '2px solid #f88',
    borderBottom: '2px solid #800',
    borderRight: '2px solid #800'
  },
  positiveBar: {
    display: 'inline-block',
    height: '12px',
    backgroundColor: '#0a0',
    borderTop: '2px solid #5a5',
    borderLeft: '2px solid #5a5',
    borderBottom: '2px solid #050',
    borderRight: '2px solid #050'
  }
};

export default ReputationGraph;
