import React, { useState, useEffect } from 'react';

/**
 * ReputationGraph - Monthly reputation visualization for writeups
 * Styles in CSS: .reputation-graph__*
 *
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
      <div className="reputation-graph">
        <div className="reputation-graph__error">
          <p>{error}</p>
        </div>
      </div>
    );
  }

  // Access denied
  if (!can_view) {
    return (
      <div className="reputation-graph">
        <div className="reputation-graph__access-denied">
          <p>You haven't voted on that writeup, so you are not allowed to see its reputation.</p>
          <p>Try clicking on the "Rep Graph" link from a writeup you have already voted on.</p>
        </div>
      </div>
    );
  }

  // Loading state
  if (loading) {
    return (
      <div className="reputation-graph">
        <p className="reputation-graph__loading">Loading reputation data...</p>
      </div>
    );
  }

  // Fetch error
  if (fetchError) {
    return (
      <div className="reputation-graph">
        <div className="reputation-graph__error">
          <p>{fetchError}</p>
        </div>
      </div>
    );
  }

  // Waiting for data
  if (!graphData) {
    return (
      <div className="reputation-graph">
        <p className="reputation-graph__loading">Loading...</p>
      </div>
    );
  }

  const isHorizontal = layout === 'horizontal';

  return (
    <div className="reputation-graph">
      <p className="reputation-graph__intro">
        You are viewing the monthly reputation graph for the following writeup:<br />
        <a href={`/?node_id=${writeup.node_id}`} className="reputation-graph__link">{writeup.title}</a>
        {' by '}
        <a href={`/?node_id=${author.node_id}`} className="reputation-graph__link">{author.title}</a>
      </p>

      <p className="reputation-graph__hint">
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
        <p className="reputation-graph__admin-note">
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
    return <p className="reputation-graph__empty">No vote data available.</p>;
  }

  // Find max values for scaling
  const maxPos = Math.max(...months.map(m => Math.max(0, m.reputation)), 1);
  const maxNeg = Math.max(...months.map(m => Math.max(0, -m.reputation)), 1);
  const scale = Math.min(1, 100 / Math.max(maxPos, maxNeg));

  return (
    <div className="reputation-graph__horizontal-container">
      <table className="reputation-graph__horizontal-table">
        <tbody>
          {/* Positive bars row */}
          <tr>
            {months.map((month, idx) => (
              <td
                key={`pos-${idx}`}
                className="reputation-graph__horizontal-cell"
                title={`${month.label} - Rep: ${month.reputation}`}
              >
                {month.reputation >= 0 && (
                  <div
                    className="reputation-graph__pos-bar"
                    style={{ height: `${Math.max(1, month.reputation * scale)}px` }}
                  />
                )}
              </td>
            ))}
          </tr>
          {/* Negative bars row */}
          <tr>
            {months.map((month, idx) => (
              <td
                key={`neg-${idx}`}
                className="reputation-graph__horizontal-cell"
                title={`${month.label} - Rep: ${month.reputation}`}
              >
                {month.reputation < 0 && (
                  <div
                    className="reputation-graph__neg-bar"
                    style={{ height: `${Math.max(1, -month.reputation * scale)}px` }}
                  />
                )}
              </td>
            ))}
          </tr>
          {/* Year labels row */}
          <tr className="reputation-graph__label-row">
            {months.map((month, idx) => (
              <td key={`label-${idx}`} className="reputation-graph__label-cell">
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
    return <p className="reputation-graph__empty">No vote data available.</p>;
  }

  // Find max values for scaling bars
  const maxUp = Math.max(...months.map(m => m.upvotes), 1);
  const maxDown = Math.max(...months.map(m => Math.abs(m.downvotes)), 1);
  const scale = Math.min(1, 100 / Math.max(maxUp, maxDown));

  return (
    <div className="reputation-graph__vertical-container">
      <table className="reputation-graph__vertical-table">
        <thead>
          <tr>
            <th className="reputation-graph__th">Date</th>
            <th className="reputation-graph__th" colSpan={2}>Downvotes</th>
            <th className="reputation-graph__th" colSpan={2}>Upvotes</th>
            <th className="reputation-graph__th">Reputation</th>
          </tr>
        </thead>
        <tbody>
          {months.map((month, idx) => (
            <tr key={idx}>
              <td className="reputation-graph__date-cell">
                {month.is_january ? <strong>{month.label}</strong> : month.label}
              </td>
              <td className="reputation-graph__downvote-label">{month.downvotes}</td>
              <td className="reputation-graph__downvote-graph">
                {month.downvotes < 0 && (
                  <span
                    className="reputation-graph__negative-bar"
                    style={{ width: `${Math.abs(month.downvotes) * scale}px` }}
                  />
                )}
              </td>
              <td className="reputation-graph__upvote-graph">
                {month.upvotes > 0 && (
                  <span
                    className="reputation-graph__positive-bar"
                    style={{ width: `${month.upvotes * scale}px` }}
                  />
                )}
              </td>
              <td className="reputation-graph__upvote-label">+{month.upvotes}</td>
              <td className="reputation-graph__reputation-label">{month.reputation}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
};

export default ReputationGraph;
