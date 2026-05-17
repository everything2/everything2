import React, { useState } from 'react';

/**
 * TheRecommender - Writeup recommendation system
 * Styles in CSS: .the-recommender__*
 *
 * Recommends writeups based on user's bookmarks and similar users.
 */
const TheRecommender = ({ data, e2 }) => {
  const {
    recommendations = [],
    target_user = '',
    pronoun = 'You',
    maxcools = 10,
    num_bookmarks_sampled = 0,
    num_friends = 0,
    error,
    target_username
  } = data;

  const [username, setUsername] = useState(target_username || '');
  const [maxCoolsInput, setMaxCoolsInput] = useState(maxcools.toString());

  const handleSubmit = (e) => {
    e.preventDefault();
    const form = e.target;
    form.submit();
  };

  return (
    <div className="the-recommender">
      <div className="the-recommender__explanation">
        <h4 className="the-recommender__heading">What It Does</h4>
        <ul className="the-recommender__list">
          <li>Takes the idea of <a href="/?node=Do+you+C!+what+I+C%3F">Do you C! what I C?</a> but pulls the user's bookmarks rather than C!s, so it's accessible to everyone.</li>
          <li>Picks up to 100 things you've bookmarked.</li>
          <li>Finds everyone else who has cooled those things, then uses the top 20 of those (your "best friends.")</li>
          <li>Finds the writeups that have been cooled by your "best friends" the most.</li>
          <li>Shows you the top 10 from that list that you haven't voted on and have less than {maxcools} C!s.</li>
        </ul>
      </div>

      <form method="POST" onSubmit={handleSubmit} className="the-recommender__form">
        <input type="hidden" name="node_id" value={e2?.node?.node_id || ''} />

        <div className="the-recommender__form-group">
          <p>Or you can enter a user name to see what we think <em>they</em> would like:</p>
          <input
            type="text"
            name="cooluser"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            className="the-recommender__text-input"
            placeholder="username"
            size="15"
            maxLength="30"
          />
        </div>

        <div className="the-recommender__form-group">
          <label className="the-recommender__label">
            Maximum C!s per writeup:{' '}
            <input
              type="number"
              name="maxcools"
              value={maxCoolsInput}
              onChange={(e) => setMaxCoolsInput(e.target.value)}
              className="the-recommender__number-input"
              min="1"
              max="100"
            />
          </label>
        </div>

        <button type="submit" className="the-recommender__button">
          Find Recommendations
        </button>
      </form>

      {error === 'user_not_found' && (
        <p className="the-recommender__error">
          Sorry, no "{target_username}" is found on the system!
        </p>
      )}

      {error === 'no_bookmarks' && (
        <p className="the-recommender__info">
          {pronoun} haven't bookmarked anything cool yet. Sorry.
        </p>
      )}

      {error === 'no_friends' && (
        <p className="the-recommender__info">
          {pronoun} don't have any "best friends" yet. Sorry.
        </p>
      )}

      {error === 'system_error' && (
        <p className="the-recommender__error">
          A system error occurred. Please try again later.
        </p>
      )}

      {!error && recommendations.length === 0 && num_bookmarks_sampled > 0 && (
        <p className="the-recommender__info">
          No new recommendations found that match your criteria. Try increasing the maximum C!s allowed.
        </p>
      )}

      {recommendations.length > 0 && (
        <div className="the-recommender__results">
          <p className="the-recommender__stats-info">
            Based on {num_bookmarks_sampled} bookmarked writeups and {num_friends} similar users:
          </p>
          <div className="the-recommender__recommendation-list">
            {recommendations.map((rec, index) => (
              <div key={rec.node_id} className="the-recommender__recommendation">
                <a href={`/?node_id=${rec.parent_id}`} className="the-recommender__parent-link">
                  {rec.parent_title}
                </a>
                {' '}
                (<a href={`/?node_id=${rec.node_id}`} className="the-recommender__writeup-link">
                  {rec.title}
                </a>)
                {' '}
                <span className="the-recommender__cool-count">
                  [{rec.cooled} C!{rec.cooled !== 1 ? 's' : ''}]
                </span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
};

export default TheRecommender;
