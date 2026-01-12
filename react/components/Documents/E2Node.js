import React from 'react'
import E2NodeDisplay from '../E2NodeDisplay'

/**
 * E2Node Document Component
 *
 * Renders an e2node page with all writeups using React-based E2 link parsing.
 * Replaces server-side Mason2 templates with client-side React.
 *
 * Data comes from Everything::Controller::e2node->display()
 */
const E2Node = ({ data, user }) => {
  if (!data) return <div>Loading...</div>

  const { e2node, existing_draft, start_with_tools_modal_open, best_entries } = data

  if (!e2node) {
    return <div className="error">E2node not found</div>
  }

  return (
    <div className="e2node-page">
      <E2NodeDisplay
        e2node={e2node}
        user={user}
        existingDraft={existing_draft}
        startWithToolsModalOpen={start_with_tools_modal_open}
        bestEntries={best_entries}
      />
    </div>
  )
}

export default E2Node
