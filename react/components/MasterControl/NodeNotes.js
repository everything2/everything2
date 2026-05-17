import React, { useState } from 'react'
import LinkNode from '../LinkNode'
import ParseLinks from '../ParseLinks'
import { FaStickyNote, FaPlus, FaTrash, FaClock } from 'react-icons/fa'

/**
 * NodeNotes - Node notes management in MasterControl
 * Styles in CSS: .node-notes__*
 */
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
      <h4 className="ns_title node-notes__title">
        <FaStickyNote size={14} /> Node Notes <em>({notes.length})</em>
      </h4>

      {error && (
        <div className="node-notes__error">
          {error}
        </div>
      )}

      <div className="node-notes__content">
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
              <p key={note.nodenote_id} className="node-notes__entry">
                {note.noter_user ? (
                  <input
                    type="checkbox"
                    id={`nodenote-select-${note.nodenote_id}`}
                    name={`nodenote-select-${note.nodenote_id}`}
                    checked={selectedNotes.has(note.nodenote_id)}
                    onChange={() => toggleNoteSelection(note.nodenote_id)}
                    disabled={isSubmitting}
                    className="node-notes__checkbox"
                  />
                ) : (
                  <span className="node-notes__bullet"> &bull; </span>
                )}
                <span className="node-notes__text">
                  <span className="node-notes__timestamp">
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
        <p className="node-notes__form-row">
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
            className="node-notes__input"
          />
          <br />
          <button
            type="submit"
            disabled={isSubmitting || !noteText.trim()}
            className="node-notes__btn node-notes__btn--add"
          >
            <FaPlus size={10} /> Add Note
          </button>
          {selectedNotes.size > 0 && (
            <button
              type="button"
              onClick={handleDeleteNotes}
              disabled={isSubmitting}
              className="node-notes__btn node-notes__btn--delete"
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
