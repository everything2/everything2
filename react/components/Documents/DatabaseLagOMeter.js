import React from 'react';

/**
 * DatabaseLagOMeter - Database performance statistics
 * Styles in CSS: .database-lag-meter__*
 */
const DatabaseLagOMeter = ({ data }) => {
  const { uptime, queries, slow_queries, slow_query_threshold, slow_per_million } = data;

  // Format numbers with commas
  const commify = (num) => {
    return num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
  };

  return (
    <div className="database-lag-meter">
      <div className="database-lag-meter__stats">
        <p className="database-lag-meter__stat-line">
          <strong>Uptime:</strong> {uptime}
        </p>
        <p className="database-lag-meter__stat-line">
          <strong>Queries:</strong> {commify(queries)}
        </p>
        <p className="database-lag-meter__stat-line">
          <strong>Slow (&gt;{slow_query_threshold} sec):</strong> {commify(slow_queries)}
        </p>
        <p className="database-lag-meter__stat-line">
          <strong>Slow/Million:</strong> {slow_per_million}
        </p>
      </div>

      <p className="database-lag-meter__description">
        Slow/Million Queries is a decent barometer of how much lag the Database is hitting.
        Rising=bad, falling=good.
      </p>
    </div>
  );
};

export default DatabaseLagOMeter;
