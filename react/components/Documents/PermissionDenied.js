import React from 'react';

/**
 * PermissionDenied - Simple permission denied message display
 * Styles in CSS: .permission-denied__*
 *
 * The message is static copy owned here (#4522); the page is a pure gate shipping only { type }.
 * A server-supplied data.message still wins for any caller not yet migrated off shipping it.
 */
const DEFAULT_MESSAGE = "You don't have access to that node.";

const PermissionDenied = ({ data }) => {
  const message = (data && data.message) || DEFAULT_MESSAGE;

  return (
    <div className="permission-denied">
      <p className="permission-denied__message">{message}</p>
    </div>
  );
};

export default PermissionDenied;
