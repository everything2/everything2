import React, { useState, useEffect, useCallback } from 'react';

/**
 * BetweenTheCracks - Find neglected writeups with few votes
 * Styles in CSS: .between-cracks__*
 * Shows writeups the user hasn't voted on that have low vote counts
 */
const BetweenTheCracks = ({ data, user }) => {
  const { error: serverError } = data;
  const isGuest = !!user?.guest;

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
    if (!isGuest) {
      fetchWriteups();
    }
  }, [isGuest, fetchWriteups]);

  // Handle form submission
  const handleSubmit = (e) => {
    e.preventDefault();
    fetchWriteups();
  };

  // Guest message
  if (isGuest) {
    return (
      <div className="between-cracks">
        <p className="between-cracks__guest-message">
          Undifferentiated from the masses of the streets, you fall between the cracks yourself.
        </p>
      </div>
    );
  }

  // Server error
  if (serverError) {
    return (
      <div className="between-cracks">
        <div className="between-cracks__error">
          <p>{serverError}</p>
        </div>
      </div>
    );
  }

  // Build reputation restriction description
  const repStr = minRep !== '' ? ` and a reputation of ${minRep} or greater` : '';

  return (
    <div className="between-cracks">
      <p className="between-cracks__intro">
        These nodes have fallen between the cracks, and seem to have gone unnoticed.
        This page lists <em>up to</em> 50 writeups that you haven't voted on that have
        fewer than {maxVotes} total vote(s){repStr} on E2. Since they have been neglected
        until now, why don't you visit them and click that vote button?
      </p>

      <form onSubmit={handleSubmit} className="between-cracks__form">
        <strong>Display writeups with </strong>
        <select
          value={maxVotes}
          onChange={(e) => setMaxVotes(parseInt(e.target.value, 10))}
          className="between-cracks__select"
        >
          {[1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map(n => (
            <option key={n} value={n}>{n}</option>
          ))}
        </select>
        <strong> (or fewer) votes and </strong>
        <select
          value={minRep}
          onChange={(e) => setMinRep(e.target.value)}
          className="between-cracks__select"
        >
          <option value="">no restriction</option>
          {[-3, -2, -1, 0, 1, 2, 3].map(n => (
            <option key={n} value={n}>{n}</option>
          ))}
        </select>
        <strong> (or greater) rep.</strong>
        <button type="submit" className="between-cracks__button" disabled={loading}>
          Go
        </button>
      </form>

      {loading && (
        <p className="between-cracks__loading">Loading writeups...</p>
      )}

      {error && (
        <div className="between-cracks__error">
          <p>{error}</p>
        </div>
      )}

      {!loading && !error && hasSearched && (
        <table className="between-cracks__table">
          <thead>
            <tr>
              <th className="between-cracks__th--center">#</th>
              <th className="between-cracks__th">Writeup</th>
              <th className="between-cracks__th">Author</th>
              <th className="between-cracks__th--center">Total Votes</th>
              <th className="between-cracks__th--right">Create Time</th>
            </tr>
          </thead>
          <tbody>
            {writeups.length === 0 ? (
              <tr>
                <td colSpan="5" className="between-cracks__empty-cell">
                  <em>You have voted on all 1000 writeups with the lowest number of votes.</em>
                </td>
              </tr>
            ) : (
              writeups.map((wu, idx) => (
                <tr key={wu.writeup_id} className={idx % 2 === 1 ? 'between-cracks__row--even' : 'between-cracks__row--odd'}>
                  <td className="between-cracks__td--center">{idx + 1}</td>
                  <td className="between-cracks__td">
                    <a href={`/?node_id=${wu.writeup_id}`} className="between-cracks__link">
                      {wu.title}
                    </a>
                  </td>
                  <td className="between-cracks__td">
                    <a href={`/?node_id=${wu.author_id}`} className="between-cracks__link">
                      {wu.author}
                    </a>
                  </td>
                  <td className="between-cracks__td--center">{wu.totalvotes}</td>
                  <td className="between-cracks__td--right">{wu.createtime}</td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      )}
    </div>
  );
};

export default BetweenTheCracks;
