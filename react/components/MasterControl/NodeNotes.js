import React, { useState } from 'react'
import LinkNode from '../LinkNode'
import ParseLinks from '../ParseLinks'
import { FaStickyNote, FaPlus, FaTrash, FaClock } from 'react-icons/fa'

const NodeNotes = ({ nodeId, initialNotes, currentUserId }) => {
  const [notes, setNotes] = useState(initialNotes || [])
  const [noteText, setNoteText] = useState('')
  const [selectedNotes, setSelectedNotes] = useState(new Set())
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [error, setError] = useState(null)

  const handleAddNote = async (e) => {
    e.preventDefault()
    if (!noteText.trim()) return

    setIsSubmitting(true)
    setError(null)

    try {
      const response = await fetch(`/api/nodenotes/${nodeId}/create`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        credentials: 'include',
        body: JSON.stringify({ notetext: noteText }),
      })

      const data = await response.json()

      if (response.ok) {
        setNotes(data.notes)
        setNoteText('')
        setSelectedNotes(new Set())
      } else {
        setError(data.error || 'Failed to add note')
      }
    } catch (err) {
      setError('Network error: ' + err.message)
    } finally {
      setIsSubmitting(false)
    }
  }

  const handleDeleteNotes = async (e) => {
    e.preventDefault()
    if (selectedNotes.size === 0) return

    setIsSubmitting(true)
    setError(null)

    try {
      let lastResponse = null

      // Delete notes one by one
      // Each DELETE returns the updated state, so we use the last response
      for (const noteId of selectedNotes) {
        const response = await fetch(`/api/nodenotes/${nodeId}/${noteId}/delete`, {
          method: 'DELETE',
          credentials: 'include',
        })

        if (!response.ok) {
          const data = await response.json()
          setError(data.error || 'Failed to delete note')
          break
        }

        lastResponse = response
      }

      // Use the updated state from the last DELETE response (no extra GET needed)
      if (lastResponse && lastResponse.ok) {
        const data = await lastResponse.json()
        setNotes(data.notes)
        setSelectedNotes(new Set())
      }
    } catch (err) {
      setError('Network error: ' + err.message)
    } finally {
      setIsSubmitting(false)
    }
  }

  const toggleNoteSelection = (noteId) => {
    const newSelection = new Set(selectedNotes)
    if (newSelection.has(noteId)) {
      newSelection.delete(noteId)
    } else {
      newSelection.add(noteId)
    }
    setSelectedNotes(newSelection)
  }

  const formatTimestamp = (timestamp) => {
    // Simple timestamp formatter - could be enhanced
    const date = new Date(timestamp)
    return date.toLocaleString()
  }

  // Group notes by node_id for display
  const groupedNotes = {}
  let currentNodeGroup = null

  notes.forEach((note) => {
    const nid = note.nodenote_nodeid
    if (!groupedNotes[nid]) {
      groupedNotes[nid] = {
        nodeId: nid,
        nodeTitle: note.node_title,
        nodeType: note.node_type,
        authorUser: note.author_user,
        notes: [],
      }
    }
    groupedNotes[nid].notes.push(note)
  })

  const noteGroups = Object.values(groupedNotes)

  return (
    <div className="nodelet_section" id="nodenotes">
      <h4 className="ns_title" style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
        <FaStickyNote size={14} /> Node Notes <em>({notes.length})</em>
      </h4>

      {error && (
        <div style={{ color: 'red', padding: '5px', marginBottom: '10px' }}>
          {error}
        </div>
      )}

      <div style={{ whiteSpace: 'normal' }}>
        {noteGroups.map((group, groupIndex) => (
          <div key={group.nodeId || `group-${groupIndex}`}>
            {groupIndex > 0 && <hr />}

            {group.nodeId !== nodeId && (
              <div>
                <b>
                  <LinkNode nodeId={group.nodeId} title={group.nodeTitle} />
                </b>
                {group.nodeType === 'writeup' && group.authorUser && (
                  <span>
                    {' '}
                    by <LinkNode type="user" nodeId={group.authorUser} />
                  </span>
                )}
              </div>
            )}

            {group.notes.map((note) => (
              <p key={note.nodenote_id} style={{ display: 'flex', alignItems: 'flex-start', gap: '4px' }}>
                {note.noter_user ? (
                  <input
                    type="checkbox"
                    id={`nodenote-select-${note.nodenote_id}`}
                    name={`nodenote-select-${note.nodenote_id}`}
                    checked={selectedNotes.has(note.nodenote_id)}
                    onChange={() => toggleNoteSelection(note.nodenote_id)}
                    disabled={isSubmitting}
                    style={{ marginTop: '3px', flexShrink: 0 }}
                  />
                ) : (
                  <span style={{ flexShrink: 0 }}> &bull; </span>
                )}
                <span style={{ flex: 1 }}>
                  <span style={{ fontSize: '0.9em', color: '#666', display: 'inline-flex', alignItems: 'center', gap: '4px' }}>
                    <FaClock size={10} /> {formatTimestamp(note.timestamp)}
                  </span>
                  {!note.legacy_format && note.noter_username && (
                    <>
                      {' '}
                      <LinkNode type="user" title={note.noter_username} />:
                    </>
                  )}{' '}
                  <ParseLinks>{note.notetext}</ParseLinks>
                </span>
              </p>
            ))}
          </div>
        ))}
      </div>

      <form onSubmit={handleAddNote}>
        <p style={{ textAlign: 'right' }}>
          <input
            type="text"
            id={`nodenote-add-${nodeId}`}
            name={`nodenote-add-${nodeId}`}
            value={noteText}
            onChange={(e) => setNoteText(e.target.value)}
            maxLength="255"
            size="22"
            placeholder="Add note..."
            disabled={isSubmitting}
            style={{ width: '100%', padding: '4px 6px', border: '1px solid #ccc', borderRadius: '3px', marginBottom: '6px' }}
          />
          <br />
          <button
            type="submit"
            disabled={isSubmitting || !noteText.trim()}
            style={{
              padding: '4px 12px',
              backgroundColor: '#5a9fd4',
              color: 'white',
              border: 'none',
              borderRadius: '3px',
              cursor: isSubmitting || !noteText.trim() ? 'not-allowed' : 'pointer',
              fontSize: '0.9em',
              display: 'inline-flex',
              alignItems: 'center',
              gap: '4px',
              opacity: isSubmitting || !noteText.trim() ? 0.6 : 1
            }}
          >
            <FaPlus size={10} /> Add Note
          </button>
          {selectedNotes.size > 0 && (
            <button
              type="button"
              onClick={handleDeleteNotes}
              disabled={isSubmitting}
              style={{
                marginLeft: '5px',
                padding: '4px 12px',
                backgroundColor: '#d9534f',
                color: 'white',
                border: 'none',
                borderRadius: '3px',
                cursor: isSubmitting ? 'not-allowed' : 'pointer',
                fontSize: '0.9em',
                display: 'inline-flex',
                alignItems: 'center',
                gap: '4px',
                opacity: isSubmitting ? 0.6 : 1
              }}
            >
              <FaTrash size={10} /> Delete ({selectedNotes.size})
            </button>
          )}
        </p>
      </form>
    </div>
  )
}

export default NodeNotes
