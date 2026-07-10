import React from 'react'

/**
 * StaffOnly - friendly soft-gate result for editor/admin-only tools (#4497).
 *
 * The server gates the DECISION (a Page returns a blank { type: 'staff_only' } payload when the
 * viewer isn't an editor/admin) and the friendly copy lives HERE, in React -- the pagestate no
 * longer ships an "Access denied…" string. The API is the real enforcement boundary; this is only
 * the soft, page-level "you can't use this tool" display.
 *
 * NB: this is NOT the "Permission Denied" node component (PermissionDenied.js) -- that renders the
 * real Permission Denied node. This is one of the per-scheme soft-gate results (staff_only /
 * admin_only / login_required / …), keyed off the gate predicate that failed.
 */
const StaffOnly = () => (
  <div className="permission-denied">
    <p className="permission-denied__message">
      This tool is available to editors and administrators.
    </p>
  </div>
)

export default StaffOnly
