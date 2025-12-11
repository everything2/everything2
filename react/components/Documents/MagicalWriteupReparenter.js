import React, { useState } from 'react'
import LinkNode from '../LinkNode'

/**
 * MagicalWriteupReparenter - Admin/Editor tool to move writeups between e2nodes
 *
 * Features:
 * - Look up source e2node by ID or title
 * - Look up destination e2node by ID or title
 * - Select writeups to move via checkboxes
 * - Auto-detect orphaned writeups and suggest parent
 * - Performs reparenting via API
 */
const MagicalWriteupReparenter = ({ data }) => {
  const {
    access_denied,
    old_e2node,
    old_writeup,
    new_e2node,
    suggested_parent,
    errors = [],
    kvl_node_id
  } = data

  const [oldE2nodeInput, setOldE2nodeInput] = useState('')
  const [oldWriteupInput, setOldWriteupInput] = useState('')
  const [newE2nodeInput, setNewE2nodeInput] = useState('')
  const [selectedWriteups, setSelectedWriteups] = useState({})
  const [feedback, setFeedback] = useState([])
  const [isLoading, setIsLoading] = useState(false)

  if (access_denied) {
    return (
      <div style={styles.container}>
        <div style={styles.errorBox}>
          Access denied. This tool is only available to editors and admins.
        </div>
      </div>
    )
  }

  // Initialize selected writeups from suggested parent auto-detection
  React.useEffect(() => {
    if (old_writeup && suggested_parent) {
      setSelectedWriteups({ [old_writeup.node_id]: true })
    }
  }, [old_writeup, suggested_parent])

  const handleLookup = (e) => {
    e.preventDefault()
    const params = new URLSearchParams()
    params.set('node_id', window.e2?.node_id || '')

    if (oldE2nodeInput) {
      params.set('old_e2node_id', oldE2nodeInput)
    } else if (oldWriteupInput) {
      params.set('old_writeup_id', oldWriteupInput)
    }

    if (newE2nodeInput) {
      params.set('new_e2node_id', newE2nodeInput)
    }

    window.location.href = `?${params.toString()}`
  }

  const handleCheckboxChange = (writeupId) => {
    setSelectedWriteups((prev) => ({
      ...prev,
      [writeupId]: !prev[writeupId]
    }))
  }

  const handleSelectAll = () => {
    const allWriteups = {}
    if (old_e2node?.writeups) {
      old_e2node.writeups.forEach((wu) => {
        allWriteups[wu.node_id] = true
      })
    }
    setSelectedWriteups(allWriteups)
  }

  const handleSelectNone = () => {
    setSelectedWriteups({})
  }

  const handleReparent = async () => {
    const writeupIds = Object.keys(selectedWriteups).filter((id) => selectedWriteups[id])

    if (writeupIds.length === 0) {
      setFeedback([{ type: 'error', text: 'Please select at least one writeup to move.' }])
      return
    }

    const destE2node = new_e2node || suggested_parent
    if (!destE2node) {
      setFeedback([{ type: 'error', text: 'Please specify a destination e2node.' }])
      return
    }

    setIsLoading(true)
    setFeedback([])

    try {
      const response = await fetch('/api/writeup_reparent/reparent', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          new_e2node_id: destE2node.node_id,
          writeup_ids: writeupIds.map((id) => parseInt(id, 10))
        })
      })

      const result = await response.json()

      if (result.success) {
        const feedbackItems = []
        const successCount = result.results.filter((r) => r.success).length
        const failCount = result.results.filter((r) => !r.success).length

        // Add summary header
        if (successCount > 0 || failCount > 0) {
          feedbackItems.push({
            type: 'header',
            text:
              successCount > 0 && failCount === 0
                ? `Successfully moved ${successCount} writeup${successCount > 1 ? 's' : ''}`
                : failCount > 0 && successCount === 0
                  ? `Failed to move ${failCount} writeup${failCount > 1 ? 's' : ''}`
                  : `Moved ${successCount}, failed ${failCount}`
          })
        }

        result.results.forEach((r) => {
          if (r.success) {
            feedbackItems.push({
              type: 'success',
              text: `Moved "${r.old_title}" to "${r.new_title}"`
            })
          } else {
            feedbackItems.push({
              type: 'error',
              text: `Failed to move writeup ${r.writeup_id}: ${r.error}`
            })
          }
        })
        setFeedback(feedbackItems)

        // Clear selected writeups after successful moves
        if (result.moved_count > 0) {
          setSelectedWriteups({})
        }
      } else {
        setFeedback([{ type: 'error', text: result.error || 'Unknown error occurred' }])
      }
    } catch (err) {
      setFeedback([{ type: 'error', text: `Network error: ${err.message}` }])
    } finally {
      setIsLoading(false)
    }
  }

  const renderWriteupList = (writeups, isSource = true) => {
    if (!writeups || writeups.length === 0) {
      return <p style={styles.nodeshell}>This e2node is a nodeshell (no writeups).</p>
    }

    return (
      <ul style={styles.writeupList}>
        {writeups.map((wu) => (
          <li key={wu.node_id} style={styles.writeupItem}>
            {isSource && (
              <input
                type="checkbox"
                checked={Boolean(selectedWriteups[wu.node_id])}
                onChange={() => handleCheckboxChange(wu.node_id)}
                style={styles.checkbox}
              />
            )}
            <LinkNode nodeId={wu.node_id} title={wu.title} />
            {' by '}
            <LinkNode nodeId={wu.author_id} title={wu.author_title} />
            <span style={styles.writeupMeta}> (id: {wu.node_id}, type: {wu.writeuptype})</span>
          </li>
        ))}
      </ul>
    )
  }

  return (
    <div style={styles.container}>
      <h2 style={styles.header}>Magical Writeup Reparenter</h2>

      {/* Error messages */}
      {errors.length > 0 && (
        <div style={styles.errorBox}>
          {errors.map((err, idx) => (
            <p key={idx}>{err}</p>
          ))}
        </div>
      )}

      {/* Feedback from reparent operation */}
      {feedback.length > 0 && (
        <div
          style={{
            ...styles.feedbackBox,
            ...(feedback.some((fb) => fb.type === 'error')
              ? styles.feedbackBoxError
              : styles.feedbackBoxSuccess)
          }}
        >
          {feedback.map((fb, idx) => (
            <p
              key={idx}
              style={
                fb.type === 'header'
                  ? styles.feedbackHeader
                  : fb.type === 'error'
                    ? styles.feedbackError
                    : styles.feedbackSuccess
              }
            >
              {fb.type === 'header' ? <strong>{fb.text}</strong> : fb.text}
            </p>
          ))}
        </div>
      )}

      {/* Lookup form */}
      <form onSubmit={handleLookup} style={styles.form}>
        <div style={styles.formSection}>
          <h3 style={styles.sectionHeader}>Source</h3>
          <div style={styles.formRow}>
            <label style={styles.label}>
              E2node ID or title:
              <input
                type="text"
                value={oldE2nodeInput}
                onChange={(e) => setOldE2nodeInput(e.target.value)}
                style={styles.input}
                placeholder="Enter e2node ID or title"
              />
            </label>
            {old_e2node && (
              <span style={styles.currentValue}>
                Current: <LinkNode nodeId={old_e2node.node_id} title={old_e2node.title} />
              </span>
            )}
          </div>
          <div style={styles.formRow}>
            <label style={styles.label}>
              - OR - Writeup ID:
              <input
                type="text"
                value={oldWriteupInput}
                onChange={(e) => setOldWriteupInput(e.target.value)}
                style={styles.input}
                placeholder="Enter writeup ID"
              />
            </label>
            {old_writeup && !old_e2node && (
              <span style={styles.orphanWarning}>
                Writeup <LinkNode nodeId={old_writeup.node_id} title={old_writeup.title} /> is
                orphaned!
              </span>
            )}
          </div>
        </div>

        <div style={styles.formSection}>
          <h3 style={styles.sectionHeader}>Destination</h3>
          <div style={styles.formRow}>
            <label style={styles.label}>
              E2node ID or title:
              <input
                type="text"
                value={newE2nodeInput}
                onChange={(e) => setNewE2nodeInput(e.target.value)}
                style={styles.input}
                placeholder="Enter destination e2node ID or title"
              />
            </label>
            {new_e2node && (
              <span style={styles.currentValue}>
                Current: <LinkNode nodeId={new_e2node.node_id} title={new_e2node.title} />
              </span>
            )}
            {suggested_parent && !new_e2node && (
              <span style={styles.suggestion}>
                Suggested:{' '}
                <LinkNode nodeId={suggested_parent.node_id} title={suggested_parent.title} />
              </span>
            )}
          </div>
        </div>

        <button type="submit" style={styles.button}>
          Look Up Nodes
        </button>
      </form>

      {/* Source writeups */}
      {old_e2node && (
        <div style={styles.section}>
          <h3 style={styles.sectionHeader}>
            Writeups in <LinkNode nodeId={old_e2node.node_id} title={old_e2node.title} />
          </h3>
          <div style={styles.buttonRow}>
            <button type="button" onClick={handleSelectAll} style={styles.smallButton}>
              Select All
            </button>
            <button type="button" onClick={handleSelectNone} style={styles.smallButton}>
              Select None
            </button>
          </div>
          {renderWriteupList(old_e2node.writeups, true)}
        </div>
      )}

      {/* Orphaned writeup */}
      {old_writeup && !old_e2node && (
        <div style={styles.section}>
          <h3 style={styles.sectionHeader}>Orphaned Writeup</h3>
          <ul style={styles.writeupList}>
            <li style={styles.writeupItem}>
              <input
                type="checkbox"
                checked={Boolean(selectedWriteups[old_writeup.node_id])}
                onChange={() => handleCheckboxChange(old_writeup.node_id)}
                style={styles.checkbox}
              />
              <LinkNode nodeId={old_writeup.node_id} title={old_writeup.title} />
              {' by '}
              <LinkNode nodeId={old_writeup.author_id} title={old_writeup.author_title} />
            </li>
          </ul>
        </div>
      )}

      {/* Destination writeups */}
      {(new_e2node || suggested_parent) && (
        <div style={styles.section}>
          <hr style={styles.hr} />
          <h3 style={styles.sectionHeader}>
            Destination:{' '}
            <LinkNode
              nodeId={(new_e2node || suggested_parent).node_id}
              title={(new_e2node || suggested_parent).title}
            />
          </h3>
          {renderWriteupList((new_e2node || suggested_parent).writeups, false)}
        </div>
      )}

      {/* Reparent button */}
      {(old_e2node || old_writeup) && (new_e2node || suggested_parent) && (
        <div style={styles.actionSection}>
          <button
            type="button"
            onClick={handleReparent}
            disabled={isLoading}
            style={isLoading ? styles.buttonDisabled : styles.actionButton}
          >
            {isLoading ? 'Moving...' : 'Move Selected Writeups'}
          </button>
        </div>
      )}

      {/* Link to Klaproth Van Lines */}
      <div style={styles.footer}>
        <p>
          Try{' '}
          {kvl_node_id ? (
            <LinkNode nodeId={kvl_node_id} title="Klaproth Van Lines" />
          ) : (
            'Klaproth Van Lines'
          )}{' '}
          for bulk moves. Certain conditions apply.
        </p>
      </div>
    </div>
  )
}

const styles = {
  container: {
    padding: '20px',
    fontSize: '13px',
    lineHeight: '1.6',
    color: '#111',
    maxWidth: '900px'
  },
  header: {
    color: '#38495e',
    marginBottom: '20px'
  },
  errorBox: {
    padding: '15px',
    backgroundColor: '#ffebee',
    border: '1px solid #f44336',
    borderRadius: '4px',
    color: '#c62828',
    marginBottom: '20px'
  },
  feedbackBox: {
    padding: '15px',
    borderRadius: '4px',
    marginBottom: '20px'
  },
  feedbackBoxSuccess: {
    backgroundColor: '#e8f5e9',
    border: '2px solid #4caf50'
  },
  feedbackBoxError: {
    backgroundColor: '#ffebee',
    border: '2px solid #f44336'
  },
  feedbackHeader: {
    fontSize: '16px',
    fontWeight: 'bold',
    margin: '0 0 10px 0',
    color: '#333'
  },
  feedbackSuccess: {
    color: '#2e7d32',
    margin: '5px 0'
  },
  feedbackError: {
    color: '#c62828',
    margin: '5px 0'
  },
  form: {
    marginBottom: '20px'
  },
  formSection: {
    padding: '15px',
    backgroundColor: '#f8f9f9',
    border: '1px solid #d3d3d3',
    borderRadius: '4px',
    marginBottom: '15px'
  },
  sectionHeader: {
    color: '#38495e',
    marginTop: '0',
    marginBottom: '15px',
    fontSize: '14px'
  },
  formRow: {
    marginBottom: '10px'
  },
  label: {
    display: 'block',
    marginBottom: '5px'
  },
  input: {
    padding: '8px',
    border: '1px solid #d3d3d3',
    borderRadius: '3px',
    fontSize: '13px',
    width: '300px',
    marginLeft: '10px'
  },
  currentValue: {
    marginLeft: '10px',
    color: '#507898'
  },
  orphanWarning: {
    marginLeft: '10px',
    color: '#c62828',
    fontWeight: 'bold'
  },
  suggestion: {
    marginLeft: '10px',
    color: '#2e7d32',
    fontStyle: 'italic'
  },
  button: {
    padding: '10px 20px',
    backgroundColor: '#38495e',
    color: '#ffffff',
    border: 'none',
    borderRadius: '3px',
    cursor: 'pointer',
    fontSize: '13px',
    fontWeight: 'bold'
  },
  smallButton: {
    padding: '5px 10px',
    backgroundColor: '#507898',
    color: '#ffffff',
    border: 'none',
    borderRadius: '3px',
    cursor: 'pointer',
    fontSize: '12px',
    marginRight: '10px'
  },
  actionButton: {
    padding: '12px 24px',
    backgroundColor: '#4060b0',
    color: '#ffffff',
    border: 'none',
    borderRadius: '3px',
    cursor: 'pointer',
    fontSize: '14px',
    fontWeight: 'bold'
  },
  buttonDisabled: {
    padding: '12px 24px',
    backgroundColor: '#cccccc',
    color: '#666666',
    border: 'none',
    borderRadius: '3px',
    cursor: 'not-allowed',
    fontSize: '14px',
    fontWeight: 'bold'
  },
  buttonRow: {
    marginBottom: '10px'
  },
  section: {
    marginTop: '20px'
  },
  writeupList: {
    listStyle: 'none',
    padding: '0',
    margin: '0'
  },
  writeupItem: {
    padding: '8px',
    borderBottom: '1px solid #e0e0e0'
  },
  checkbox: {
    marginRight: '10px'
  },
  writeupMeta: {
    color: '#507898',
    fontSize: '11px',
    marginLeft: '5px'
  },
  nodeshell: {
    color: '#507898',
    fontStyle: 'italic'
  },
  hr: {
    border: 'none',
    borderTop: '1px solid #d3d3d3',
    margin: '20px 0'
  },
  actionSection: {
    marginTop: '20px',
    padding: '15px',
    backgroundColor: '#e3f2fd',
    border: '1px solid #2196f3',
    borderRadius: '4px',
    textAlign: 'center'
  },
  footer: {
    marginTop: '30px',
    padding: '15px',
    backgroundColor: '#f5f5f5',
    borderRadius: '4px',
    fontSize: '12px',
    color: '#666'
  }
}

export default MagicalWriteupReparenter
