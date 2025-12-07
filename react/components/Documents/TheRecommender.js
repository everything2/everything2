import React, { useState } from 'react';

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
    <div style={styles.container}>
      <div style={styles.explanation}>
        <h4 style={styles.heading}>What It Does</h4>
        <ul style={styles.list}>
          <li>Takes the idea of <a href="/?node=Do+you+C!+what+I+C%3F">Do you C! what I C?</a> but pulls the user's bookmarks rather than C!s, so it's accessible to everyone.</li>
          <li>Picks up to 100 things you've bookmarked.</li>
          <li>Finds everyone else who has cooled those things, then uses the top 20 of those (your "best friends.")</li>
          <li>Finds the writeups that have been cooled by your "best friends" the most.</li>
          <li>Shows you the top 10 from that list that you haven't voted on and have less than {maxcools} C!s.</li>
        </ul>
      </div>

      <form method="POST" onSubmit={handleSubmit} style={styles.form}>
        <input type="hidden" name="node_id" value={e2?.node?.node_id || ''} />

        <div style={styles.formGroup}>
          <p>Or you can enter a user name to see what we think <em>they</em> would like:</p>
          <input
            type="text"
            name="cooluser"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            style={styles.textInput}
            placeholder="username"
            size="15"
            maxLength="30"
          />
        </div>

        <div style={styles.formGroup}>
          <label style={styles.label}>
            Maximum C!s per writeup:{' '}
            <input
              type="number"
              name="maxcools"
              value={maxCoolsInput}
              onChange={(e) => setMaxCoolsInput(e.target.value)}
              style={styles.numberInput}
              min="1"
              max="100"
            />
          </label>
        </div>

        <button type="submit" style={styles.button}>
          Find Recommendations
        </button>
      </form>

      {error === 'user_not_found' && (
        <p style={styles.error}>
          Sorry, no "{target_username}" is found on the system!
        </p>
      )}

      {error === 'no_bookmarks' && (
        <p style={styles.info}>
          {pronoun} haven't bookmarked anything cool yet. Sorry.
        </p>
      )}

      {error === 'no_friends' && (
        <p style={styles.info}>
          {pronoun} don't have any "best friends" yet. Sorry.
        </p>
      )}

      {error === 'system_error' && (
        <p style={styles.error}>
          A system error occurred. Please try again later.
        </p>
      )}

      {!error && recommendations.length === 0 && num_bookmarks_sampled > 0 && (
        <p style={styles.info}>
          No new recommendations found that match your criteria. Try increasing the maximum C!s allowed.
        </p>
      )}

      {recommendations.length > 0 && (
        <div style={styles.results}>
          <p style={styles.statsInfo}>
            Based on {num_bookmarks_sampled} bookmarked writeups and {num_friends} similar users:
          </p>
          <div style={styles.recommendationList}>
            {recommendations.map((rec, index) => (
              <div key={rec.node_id} style={styles.recommendation}>
                <a href={`/?node_id=${rec.parent_id}`} style={styles.parentLink}>
                  {rec.parent_title}
                </a>
                {' '}
                (<a href={`/?node_id=${rec.node_id}`} style={styles.writeupLink}>
                  {rec.title}
                </a>)
                {' '}
                <span style={styles.coolCount}>
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

const styles = {
  container: {
    maxWidth: '900px',
    margin: '0 auto',
    padding: '20px',
    fontSize: '16px',
    lineHeight: '1.6',
    color: '#111111'
  },
  explanation: {
    marginBottom: '20px',
    padding: '15px',
    background: '#f8f9f9',
    border: '1px solid #dee2e6',
    borderRadius: '4px'
  },
  heading: {
    margin: '0 0 10px 0',
    fontSize: '18px',
    color: '#38495e'
  },
  list: {
    margin: '0',
    paddingLeft: '25px'
  },
  form: {
    marginBottom: '20px',
    padding: '15px',
    background: '#f8f9f9',
    border: '1px solid #dee2e6',
    borderRadius: '4px'
  },
  formGroup: {
    marginBottom: '15px'
  },
  label: {
    fontSize: '14px',
    color: '#111111'
  },
  textInput: {
    padding: '6px 10px',
    fontSize: '14px',
    border: '1px solid #dee2e6',
    borderRadius: '4px',
    marginLeft: '5px'
  },
  numberInput: {
    padding: '6px 10px',
    fontSize: '14px',
    border: '1px solid #dee2e6',
    borderRadius: '4px',
    width: '80px',
    marginLeft: '5px'
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
  error: {
    color: '#dc3545',
    fontWeight: 'bold',
    padding: '10px',
    background: '#fff5f5',
    border: '1px solid #dc3545',
    borderRadius: '4px'
  },
  info: {
    color: '#507898',
    padding: '10px',
    background: '#f8f9f9',
    border: '1px solid #dee2e6',
    borderRadius: '4px'
  },
  results: {
    marginTop: '20px'
  },
  statsInfo: {
    fontSize: '14px',
    color: '#507898',
    marginBottom: '15px',
    fontStyle: 'italic'
  },
  recommendationList: {
    display: 'flex',
    flexDirection: 'column',
    gap: '10px'
  },
  recommendation: {
    padding: '10px',
    background: '#ffffff',
    border: '1px solid #dee2e6',
    borderRadius: '4px',
    lineHeight: '1.8'
  },
  parentLink: {
    color: '#4060b0',
    fontWeight: 'bold',
    textDecoration: 'none'
  },
  writeupLink: {
    color: '#4060b0',
    textDecoration: 'none'
  },
  coolCount: {
    fontSize: '13px',
    color: '#507898',
    fontStyle: 'italic'
  }
};

export default TheRecommender;
