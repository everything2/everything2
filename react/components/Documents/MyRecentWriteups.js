import React from 'react';

/**
 * MyRecentWriteups - User writeup count since last year
 * Styles in CSS: .my-recent-writeups__*
 */
const MyRecentWriteups = ({ data, user = {} }) => {
  const { is_guest, message, writeup_count, one_year_ago } = data;
  const user_id = user.node_id;

  if (is_guest) {
    return (
      <div className="my-recent-writeups">
        <p className="my-recent-writeups__guest-message">{message}</p>
      </div>
    );
  }

  return (
    <div className="my-recent-writeups">
      <p className="my-recent-writeups__text">
        Since one year ago, on <strong>{one_year_ago}</strong>,{' '}
        <a href={`/?node_id=${user_id}`} className="my-recent-writeups__link">you</a> have published{' '}
        <strong>{writeup_count}</strong> writeup{writeup_count !== 1 ? 's' : ''}.
      </p>
    </div>
  );
};

export default MyRecentWriteups;
