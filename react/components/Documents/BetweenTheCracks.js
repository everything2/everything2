import React, { useState, useEffect, useCallback } from 'react';

/**
 * BetweenTheCracks - Find neglected writeups with few votes
 * Shows writeups the user hasn't voted on that have low vote counts
 */
const BetweenTheCracks = ({ data }) => {
  const { is_guest, error: serverError } = data;

  const [maxVotes, setMaxVotes] = useState(5);
  const [minRep, setMinRep] = useState('');
  const [writeups, setWriteups] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [hasSearched, setHasSearched] = useState(false);

  // Fetch writeups from API
  const fetchWriteups = useCallback(async () => {
    setLoading(true);
    setError(null);

    try {
      let url = `/api/betweenthecracks/search?max_votes=${maxVotes}`;
      if (minRep !== '') {
        url += `&min_rep=${minRep}`;
      }

      const response = await fetch(url);
      const result = await response.json();

      if (result.success) {
        setWriteups(result.data.writeups);
      } else {
        setError(result.error || 'Failed to fetch writeups');
      }
    } catch (err) {
      setError('Network error: ' + err.message);
    } finally {
      setLoading(false);
      setHasSearched(true);
    }
  }, [maxVotes, minRep]);

  // Initial fetch on mount
  useEffect(() => {
    if (!is_guest) {
      fetchWriteups();
    }
  }, [is_guest, fetchWriteups]);

  // Handle form submission
  const handleSubmit = (e) => {
    e.preventDefault();
    fetchWriteups();
  };

  // Guest message
  if (is_guest) {
    return (
      <div style={styles.container}>
        <p style={styles.guestMessage}>
          Undifferentiated from the masses of the streets, you fall between the cracks yourself.
        </p>
      </div>
    );
  }

  // Server error
  if (serverError) {
    return (
      <div style={styles.container}>
        <div style={styles.error}>
          <p>{serverError}</p>
        </div>
      </div>
    );
  }

  // Build reputation restriction description
  const repStr = minRep !== '' ? ` and a reputation of ${minRep} or greater` : '';

  return (
    <div style={styles.container}>
      <p style={styles.intro}>
        These nodes have fallen between the cracks, and seem to have gone unnoticed.
        This page lists <em>up to</em> 50 writeups that you haven't voted on that have
        fewer than {maxVotes} total vote(s){repStr} on E2. Since they have been neglected
        until now, why don't you visit them and click that vote button?
      </p>

      <form onSubmit={handleSubmit} style={styles.form}>
        <strong>Display writeups with </strong>
        <select
          value={maxVotes}
          onChange={(e) => setMaxVotes(parseInt(e.target.value, 10))}
          style={styles.select}
        >
          {[1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map(n => (
            <option key={n} value={n}>{n}</option>
          ))}
        </select>
        <strong> (or fewer) votes and </strong>
        <select
          value={minRep}
          onChange={(e) => setMinRep(e.target.value)}
          style={styles.select}
        >
          <option value="">no restriction</option>
          {[-3, -2, -1, 0, 1, 2, 3].map(n => (
            <option key={n} value={n}>{n}</option>
          ))}
        </select>
        <strong> (or greater) rep.</strong>
        <button type="submit" style={styles.button} disabled={loading}>
          Go
        </button>
      </form>

      {loading && (
        <p style={styles.loading}>Loading writeups...</p>
      )}

      {error && (
        <div style={styles.error}>
          <p>{error}</p>
        </div>
      )}

      {!loading && !error && hasSearched && (
        <table style={styles.table}>
          <thead>
            <tr>
              <th style={styles.thCenter}>#</th>
              <th style={styles.th}>Writeup</th>
              <th style={styles.th}>Author</th>
              <th style={styles.thCenter}>Total Votes</th>
              <th style={styles.thRight}>Create Time</th>
            </tr>
          </thead>
          <tbody>
            {writeups.length === 0 ? (
              <tr>
                <td colSpan="5" style={styles.emptyCell}>
                  <em>You have voted on all 1000 writeups with the lowest number of votes.</em>
                </td>
              </tr>
            ) : (
              writeups.map((wu, idx) => (
                <tr key={wu.writeup_id} style={idx % 2 === 1 ? styles.evenRow : styles.oddRow}>
                  <td style={styles.tdCenter}>{idx + 1}</td>
                  <td style={styles.td}>
                    <a href={`/?node_id=${wu.writeup_id}`} style={styles.link}>
                      {wu.title}
                    </a>
                  </td>
                  <td style={styles.td}>
                    <a href={`/?node_id=${wu.author_id}`} style={styles.link}>
                      {wu.author}
                    </a>
                  </td>
                  <td style={styles.tdCenter}>{wu.totalvotes}</td>
                  <td style={styles.tdRight}>{wu.createtime}</td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      )}
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
    color: '#38495e',
    lineHeight: '1.5'
  },
  guestMessage: {
    padding: '20px',
    fontStyle: 'italic',
    color: '#507898',
    textAlign: 'center'
  },
  form: {
    marginBottom: '20px',
    padding: '12px',
    background: '#f8f9f9',
    borderRadius: '4px'
  },
  select: {
    margin: '0 4px',
    padding: '4px 8px'
  },
  button: {
    marginLeft: '12px',
    padding: '4px 16px',
    cursor: 'pointer'
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
  table: {
    width: '100%',
    borderCollapse: 'collapse',
    fontSize: '13px'
  },
  th: {
    padding: '8px 12px',
    fontWeight: '600',
    color: '#38495e',
    background: '#f8f9f9',
    borderBottom: '2px solid #dee2e6',
    textAlign: 'left'
  },
  thCenter: {
    padding: '8px 12px',
    fontWeight: '600',
    color: '#38495e',
    background: '#f8f9f9',
    borderBottom: '2px solid #dee2e6',
    textAlign: 'center'
  },
  thRight: {
    padding: '8px 12px',
    fontWeight: '600',
    color: '#38495e',
    background: '#f8f9f9',
    borderBottom: '2px solid #dee2e6',
    textAlign: 'right'
  },
  td: {
    padding: '6px 12px',
    borderBottom: '1px solid #eee'
  },
  tdCenter: {
    padding: '6px 12px',
    borderBottom: '1px solid #eee',
    textAlign: 'center'
  },
  tdRight: {
    padding: '6px 12px',
    borderBottom: '1px solid #eee',
    textAlign: 'right'
  },
  emptyCell: {
    padding: '20px',
    textAlign: 'center',
    color: '#6c757d'
  },
  evenRow: {
    background: '#f8f9f9'
  },
  oddRow: {
    background: '#fff'
  },
  link: {
    color: '#4060b0',
    textDecoration: 'none'
  }
};

export default BetweenTheCracks;
