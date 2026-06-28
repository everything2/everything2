import React from 'react';

/**
 * RandomNodeshells - Random nodeshell generator
 * Styles in CSS: .random-nodeshells__*
 */
const RandomNodeshells = ({ data, user }) => {
  const { message, num_searched, num_found, nodeshells = [] } = data;
  const isGuest = !!user?.guest;

  if (isGuest) {
    return (
      <div className="random-nodeshells">
        <p className="random-nodeshells__guest-message">{message}</p>
      </div>
    );
  }

  return (
    <div className="random-nodeshells">
      <div className="random-nodeshells__section">
        <p><strong>How this works:</strong></p>
        <p className="random-nodeshells__description">
          The code picks {num_searched} random possible node_ids, then checks if the node_id
          actually exists, if it is an e2node nodetype, and if it has no writeups and no firmlinks.
          Interestingly, this usually produces between 30 and 40 nodeshells with pretty good consistency.
        </p>
      </div>

      <p>
        <a href="?node=Random%20nodeshells">Generate a new list</a>
      </p>

      <p className="random-nodeshells__result-text">
        Here are <strong>{num_found}</strong> random nodeshells:
      </p>

      <ul className="random-nodeshells__list">
        {nodeshells.map((nodeshell) => (
          <li key={nodeshell.node_id}>
            <a href={`/?node_id=${nodeshell.node_id}`}>{nodeshell.title}</a>
          </li>
        ))}
      </ul>
    </div>
  );
};

export default RandomNodeshells;
