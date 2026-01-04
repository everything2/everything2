import React from 'react'
import SystemNodeEditor from '../SystemNodeEditor'

/**
 * BasicEdit - React wrapper for basicedit displaytype
 *
 * Renders the SystemNodeEditor component for gods to edit
 * raw database fields of any node type. This is the React
 * equivalent of the legacy node_basicedit_page.
 *
 * Props:
 * - data: { type: 'basicedit', node_id, title, nodeType }
 */

const BasicEdit = ({ data }) => {
  const { node_id, title, nodeType } = data

  const handleSave = (result) => {
    // Optionally show success message or refresh
    console.log('Saved:', result)
  }

  const handleCancel = () => {
    // Navigate back to display view
    window.location.href = `/node/${node_id}`
  }

  return (
    <div className="basic-edit-page">
      <SystemNodeEditor
        nodeId={node_id}
        onSave={handleSave}
        onCancel={handleCancel}
      />
    </div>
  )
}

export default BasicEdit
