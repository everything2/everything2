import React, { useState, useEffect } from 'react';

/**
 * ReputationGraph - Monthly reputation visualization for writeups.
 * Styles in CSS: .reputation-graph__*
 *
 * Fully client-resolved (#4504): the Page ships only { type, layout }; this reads the writeup `id`
 * off the URL and fetches GET /api/reputation/votes, which returns the writeup + author metadata,
 * enforces the per-user permission, and returns the monthly vote data. Supports horizontal (bar) and
 * vertical (table) layouts, selected by the page-provided `layout`.
 */
const ReputationGraph = ({ data, user }) => {
  const { layout = 'vertical' } = data;
  const isAdmin = !!user?.admin;

  const [graphData, setGraphData] = useState(null); // { writeup, author, months }
  const [loading, setLoading] = useState(true);
  const [errorMessage, setErrorMessage] = useState(null);
  // One component renders both layouts (#4504): the Page seeds the initial view (the "Reputation
  // Graph" node -> vertical, "Reputation Graph Horizontal" -> horizontal), and the pill lets the
  // reader switch client-side without navigating.
  const [view, setView] = useState(layout === 'horizontal' ? 'horizontal' : 'vertical');

  useEffect(() => {
    const id = new URLSearchParams(window.location.search).get('id');
    if (!id) {
      setErrorMessage(friendlyError('Invalid writeup ID'));
      setLoading(false);
      return undefined;
    }

    let cancelled = false;
    (async () => {
      try {
        const response = await fetch(`/api/reputation/votes?writeup_id=${encodeURIComponent(id)}`, {
          credentials: 'same-origin'
        });
        const result = await response.json();
        if (cancelled) return;
        if (result.success) {
          setGraphData(result.data);
        } else {
          setErrorMessage(friendlyError(result.error));
        }
      } catch (err) {
        if (!cancelled) setErrorMessage('Network error: ' + err.message);
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();

    return () => {
      cancelled = true;
    };
  }, []);

  if (loading) {
    return (
      <div className="reputation-graph">
        <p className="reputation-graph__loading">Loading reputation data...</p>
      </div>
    );
  }

  if (errorMessage) {
    return (
      <div className="reputation-graph">
        <div className="reputation-graph__error">
          <p>{errorMessage}</p>
        </div>
      </div>
    );
  }

  const { writeup, author } = graphData;
  const isHorizontal = view === 'horizontal';

  return (
    <div className="reputation-graph">
      <p className="reputation-graph__intro">
        You are viewing the monthly reputation graph for the following writeup:<br />
        <a href={`/?node_id=${writeup.node_id}`} className="reputation-graph__link">{writeup.title}</a>
        {' by '}
        <a href={`/?node_id=${author.node_id}`} className="reputation-graph__link">{author.title}</a>
      </p>

      <div className="reputation-graph__view-toggle" role="group" aria-label="Graph layout">
        <button
          type="button"
          className={`reputation-graph__view-pill${!isHorizontal ? ' reputation-graph__view-pill--active' : ''}`}
          aria-pressed={!isHorizontal}
          onClick={() => setView('vertical')}
        >
          Table
        </button>
        <button
          type="button"
          className={`reputation-graph__view-pill${isHorizontal ? ' reputation-graph__view-pill--active' : ''}`}
          aria-pressed={isHorizontal}
          onClick={() => setView('horizontal')}
        >
          Chart
        </button>
      </div>

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

      {isAdmin && (
        <p className="reputation-graph__admin-note">
          NOTE: Admins can view the graph of any writeup by simply appending "&id=&lt;writeup_id&gt;" to the end of the URL
        </p>
      )}
    </div>
  );
};

// Map the API's terse error to the user-facing guidance the page used to show.
const friendlyError = (err) => {
  if (err === 'Access denied') {
    return "You haven't voted on that writeup, so you are not allowed to see its reputation. Try clicking the \"Rep Graph\" link from a writeup you have already voted on.";
  }
  if (err === 'Node is not a writeup') {
    return 'You can only view the reputation graph for writeups. Try clicking the "Rep Graph" link from a writeup you have already voted on.';
  }
  // Invalid writeup ID / Writeup not found / missing id
  return 'Not a valid node. Try clicking the "Rep Graph" link from a writeup you have already voted on.';
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
          {/* Cumulative reputation value per month */}
          <tr className="reputation-graph__value-row">
            {months.map((month, idx) => (
              <td
                key={`val-${idx}`}
                className="reputation-graph__value-cell"
                title={month.label}
              >
                {month.reputation}
              </td>
            ))}
          </tr>
          {/* Year labels row (marked at each January) */}
          <tr className="reputation-graph__label-row">
            {months.map((month, idx) => (
              <td key={`label-${idx}`} className="reputation-graph__label-cell">
                {month.is_january ? month.year : ''}
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
