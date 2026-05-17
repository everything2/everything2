import React from 'react';

/**
 * PermissionDenied - Simple permission denied message display
 * Styles in CSS: .permission-denied__*
 */
const PermissionDenied = ({ data }) => {
  const { message } = data;

  return (
    <div className="permission-denied">
      <p className="permission-denied__message">{message}</p>
    </div>
  );
};

export default PermissionDenied;
