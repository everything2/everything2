import React, { useState } from 'react';

/**
 * DoYouCWhatIC - C! recommendation engine
 * Styles in CSS: .do-you-c__*
 */
const DoYouCWhatIC = ({ data, e2 }) => {
  const {
    recommendations = [],
    target_user = '',
    pronoun = 'You',
    maxcools = 10,
    num_cools_sampled = 0,
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
    <div className="do-you-c">
      <div className="do-you-c__explanation">
        <h4 className="do-you-c__heading">What It Does</h4>
        <ul className="do-you-c__list">
          <li>Picks up to 100 things you've cooled.</li>
          <li>Finds everyone else who has cooled those things, too, then uses the top 20 of those (your "best friends.")</li>
          <li>Finds the writeups that have been cooled by your "best friends" the most.</li>
          <li>Shows you the top 10 from that list that you haven't voted on and have less than {maxcools} C!s.</li>
        </ul>
      </div>

      <form method="POST" onSubmit={handleSubmit} className="do-you-c__form">
        <input type="hidden" name="node_id" value={e2?.node?.node_id || ''} />

        <div className="do-you-c__form-group">
          <p>Or you can enter a user name to see what we think <em>they</em> would like:</p>
          <input
            type="text"
            name="cooluser"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            className="do-you-c__text-input"
            placeholder="username"
            size="15"
            maxLength="30"
          />
        </div>

        <div className="do-you-c__form-group">
          <label className="do-you-c__label">
            Maximum C!s per writeup:{' '}
            <input
              type="number"
              name="maxcools"
              value={maxCoolsInput}
              onChange={(e) => setMaxCoolsInput(e.target.value)}
              className="do-you-c__number-input"
              min="1"
              max="100"
            />
          </label>
        </div>

        <button type="submit" className="do-you-c__button">
          Find Recommendations
        </button>
      </form>

      {error === 'user_not_found' && (
        <p className="do-you-c__error">
          Sorry, no '{target_username}' is found on the system!
        </p>
      )}

      {error === 'no_cools' && (
        <p className="do-you-c__info">
          {pronoun} haven't cooled anything yet. Sorry - you might like to try{' '}
          <a href="/?node=The+Recommender">The Recommender</a>, which uses bookmarks, instead.
        </p>
      )}

      {error === 'no_friends' && (
        <p className="do-you-c__info">
          {pronoun} don't have any 'best friends' yet. Sorry.
        </p>
      )}

      {!error && recommendations.length === 0 && num_cools_sampled > 0 && (
        <p className="do-you-c__info">
          No new recommendations found that match your criteria. Try increasing the maximum C!s allowed.
        </p>
      )}

      {recommendations.length > 0 && (
        <div className="do-you-c__results">
          <p className="do-you-c__stats-info">
            Based on {num_cools_sampled} cooled writeups and {num_friends} similar users:
          </p>
          <div className="do-you-c__recommendation-list">
            {recommendations.map((rec, index) => (
              <div key={rec.node_id} className="do-you-c__recommendation">
                <a href={`/?node_id=${rec.parent_id}`} className="do-you-c__parent-link">
                  {rec.parent_title}
                </a>
                {' '}
                (<a href={`/?node_id=${rec.node_id}`} className="do-you-c__writeup-link">
                  {rec.title}
                </a>)
                {' '}
                <span className="do-you-c__cool-count">
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

export default DoYouCWhatIC;
