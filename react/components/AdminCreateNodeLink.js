import React from 'react';

/**
 * AdminCreateNodeLink - Shows "create any type of node" link for admins
 *
 * Used on search results pages (Findings, NothingFound) to give admins
 * quick access to create any node type.
 */
const AdminCreateNodeLink = ({ user, searchTerm, style }) => {
  if (!user?.admin) {
    return null;
  }

  return (
    <p style={style || styles.default}>
      Lucky you, you can{' '}
      <strong>
        <a href={`/?node=create%20node&newtitle=${encodeURIComponent(searchTerm || '')}`}>
          create any type of node...
        </a>
      </strong>
    </p>
  );
};

const styles = {
  default: {
    marginTop: '15px',
    fontSize: '16px'
  }
};

export default AdminCreateNodeLink;
