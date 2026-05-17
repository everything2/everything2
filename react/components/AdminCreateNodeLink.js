import React from 'react';

/**
 * AdminCreateNodeLink - Shows "create any type of node" link for admins
 * Styles in CSS: .admin-create-node-link
 *
 * Used on search results pages (Findings, NothingFound) to give admins
 * quick access to create any node type.
 */
const AdminCreateNodeLink = ({ user, searchTerm, className }) => {
  if (!user?.admin) {
    return null;
  }

  return (
    <p className={className || 'admin-create-node-link'}>
      Lucky you, you can{' '}
      <strong>
        <a href={`/?node=create%20node&newtitle=${encodeURIComponent(searchTerm || '')}`}>
          create any type of node...
        </a>
      </strong>
    </p>
  );
};

export default AdminCreateNodeLink;
