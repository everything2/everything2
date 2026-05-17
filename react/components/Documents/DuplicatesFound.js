import React, { useEffect } from 'react';

/**
 * DuplicatesFound - Shows multiple nodes with the same title
 * Styles in CSS: .duplicates-found__*
 */
const DuplicatesFound = ({ data }) => {
  const { redirect_to_nothing_found, redirect_to_node, search_term, matches = [], lastnode_id } = data;

  // Handle redirects
  useEffect(() => {
    if (redirect_to_nothing_found) {
      // Redirect to nothing_found - this should be handled by the controller
      // but we can show a message as fallback
      return;
    }
    if (redirect_to_node) {
      window.location.href = `/?node_id=${redirect_to_node}${lastnode_id ? `&lastnode_id=${lastnode_id}` : ''}`;
    }
  }, [redirect_to_nothing_found, redirect_to_node, lastnode_id]);

  if (redirect_to_nothing_found) {
    return (
      <div className="duplicates-found">
        <p>No matches found.</p>
      </div>
    );
  }

  if (redirect_to_node) {
    return (
      <div className="duplicates-found">
        <p>Redirecting...</p>
      </div>
    );
  }

  return (
    <div className="duplicates-found">
      <p className="duplicates-found__header">
        Multiple nodes named "{search_term}" were found:
      </p>

      <table className="duplicates-found__table">
        <thead>
          <tr>
            <th className="duplicates-found__th">node_id</th>
            <th className="duplicates-found__th">title</th>
            <th className="duplicates-found__th">type</th>
            <th className="duplicates-found__th">author</th>
            <th className="duplicates-found__th">createtime</th>
          </tr>
        </thead>
        <tbody>
          {matches.map((match, index) => (
            <tr key={match.node_id} className={index % 2 === 0 ? 'duplicates-found__row--even' : 'duplicates-found__row--odd'}>
              <td className="duplicates-found__td">{match.node_id}</td>
              <td className="duplicates-found__td">
                <a href={`/?node_id=${match.node_id}${lastnode_id ? `&lastnode_id=${lastnode_id}` : ''}`}>
                  {match.title}
                </a>
              </td>
              <td className="duplicates-found__td">{match.type}</td>
              <td className="duplicates-found__td">
                {match.author_user > 0 ? (
                  match.is_current_user ? (
                    <strong>
                      <a href={`/?node_id=${match.author_user}&lastnode_id=0`}>
                        {match.author_name}
                      </a>
                    </strong>
                  ) : (
                    <a href={`/?node_id=${match.author_user}&lastnode_id=0`}>
                      {match.author_name}
                    </a>
                  )
                ) : ''}
              </td>
              <td className="duplicates-found__td">{match.createtime}</td>
            </tr>
          ))}
        </tbody>
      </table>

      <div className="duplicates-found__explanation">
        <p>On Everything2, different things can have the same title. For example, a user could
        have the name "aardvark", but there could also be a page full of writeups called "aardvark".</p>

        <p>If you are looking for information about a topic, choose <strong>e2node</strong>;
        this is where people's writeups are shown.<br />
        If you want to see a user's profile, pick <strong>user</strong>.<br />
        Other types of page, such as <strong>superdoc</strong>, are special and may be
        interactive or help keep the site running.</p>
      </div>
    </div>
  );
};

export default DuplicatesFound;
