import React, { useState } from 'react'
import WriteupDisplay from '../WriteupDisplay'
import InlineWriteupEditor from '../InlineWriteupEditor'
import PublishModal from './PublishModal'
import LinkNode from '../LinkNode'
import { FaEdit, FaTrash, FaPaperPlane } from 'react-icons/fa'

/**
 * Draft Document Component
 *
 * Renders a draft page using React-based E2 link parsing.
 * Replaces legacy htmlpage draft_display_page with client-side React.
 *
 * Data comes from Everything::Controller::draft
 *
 * Features:
 * - Display draft content with E2 link parsing (via WriteupDisplay with isDraft prop)
 * - Edit button for author/editors
 * - Publish button for author
 * - Delete button for author
 * - Shows publication status badge
 * - Shows parent e2node if linked
 */

const Draft = ({ data }) => {
  const [isEditing, setIsEditing] = useState(false)
  const [currentDoctext, setCurrentDoctext] = useState(null)
  const [isDeleting, setIsDeleting] = useState(false)
  const [deleteError, setDeleteError] = useState(null)
  const [showPublishModal, setShowPublishModal] = useState(false)

  if (!data) return <div>Loading...</div>

  const { draft, user } = data

  if (!draft) {
    return <div className="error">Draft not found</div>
  }

  // Use currentDoctext if set (after editing), otherwise use original
  const displayDoctext = currentDoctext !== null ? currentDoctext : draft.doctext

  const isGuest = !user || user.is_guest
  const isAuthor = draft.is_author
  const canEdit = draft.can_edit
  const authorName = draft.author?.title || 'Unknown'

  // Handle delete
  const handleDelete = async () => {
    if (!window.confirm('Are you sure you want to permanently delete this draft?')) {
      return
    }

    setIsDeleting(true)
    setDeleteError(null)

    try {
      const response = await fetch(`/api/drafts/${draft.node_id}`, {
        method: 'DELETE',
        credentials: 'include'
      })

      const result = await response.json()

      if (result.success) {
        // Redirect to drafts list
        window.location.href = '/node/superdoc/Drafts'
      } else {
        setDeleteError(result.error || 'Failed to delete draft')
        setIsDeleting(false)
      }
    } catch (err) {
      setDeleteError(err.message)
      setIsDeleting(false)
    }
  }

  // Transform draft data to writeup-compatible format for WriteupDisplay
  const writeupData = {
    node_id: draft.node_id,
    title: draft.title,
    doctext: displayDoctext,
    author: draft.author,
    createtime: draft.createtime
  }

  return (
    <div className="draft-page">
      {/* Toolbar */}
      {Boolean(canEdit) && !isEditing && (
        <div style={{ textAlign: 'right', marginBottom: '8px', display: 'flex', justifyContent: 'flex-end', gap: '8px' }}>
          <button
            onClick={() => setIsEditing(true)}
            title={isAuthor ? 'Edit your draft' : `Edit ${authorName}'s draft`}
            style={{
              background: 'none',
              border: 'none',
              cursor: 'pointer',
              fontSize: '16px',
              color: '#507898',
              padding: '2px 4px',
              display: 'inline-flex',
              alignItems: 'center',
              justifyContent: 'center'
            }}
          >
            <FaEdit />
          </button>
          {Boolean(isAuthor) && (
            <>
              <button
                onClick={() => setShowPublishModal(true)}
                title="Publish this draft"
                style={{
                  background: 'none',
                  border: 'none',
                  cursor: 'pointer',
                  fontSize: '16px',
                  color: '#28a745',
                  padding: '2px 4px',
                  display: 'inline-flex',
                  alignItems: 'center',
                  justifyContent: 'center'
                }}
              >
                <FaPaperPlane />
              </button>
              <button
                onClick={handleDelete}
                disabled={isDeleting}
                title="Delete this draft"
                style={{
                  background: 'none',
                  border: 'none',
                  cursor: isDeleting ? 'wait' : 'pointer',
                  fontSize: '16px',
                  color: '#dc3545',
                  padding: '2px 4px',
                  display: 'inline-flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  opacity: isDeleting ? 0.5 : 1
                }}
              >
                <FaTrash />
              </button>
            </>
          )}
        </div>
      )}

      {/* Delete error message */}
      {deleteError && (
        <div style={{ color: '#dc3545', marginBottom: '10px', padding: '10px', backgroundColor: '#f8d7da', borderRadius: '4px' }}>
          Error: {deleteError}
        </div>
      )}

      {/* Parent e2node info if linked */}
      {!isEditing && draft.parent_e2node && (
        <div style={{ padding: '8px 0', fontSize: '13px', color: '#666', borderBottom: '1px solid #eee' }}>
          Draft for: <LinkNode nodeId={draft.parent_e2node.node_id} title={draft.parent_e2node.title} type="e2node" />
        </div>
      )}

      {/* Collaborators info if present */}
      {!isEditing && draft.collaborators && (
        <div style={{ padding: '8px 0', fontSize: '13px', color: '#666', borderBottom: '1px solid #eee' }}>
          Collaborators: {draft.collaborators}
        </div>
      )}

      {/* Show editor or draft display */}
      {isEditing ? (
        <InlineWriteupEditor
          e2nodeId={draft.parent_e2node?.node_id}
          e2nodeTitle={draft.parent_e2node?.title || draft.title}
          initialContent={displayDoctext || ''}
          draftId={draft.node_id}
          onSave={(newContent) => {
            if (newContent !== undefined) {
              setCurrentDoctext(newContent)
            }
            setIsEditing(false)
          }}
          onCancel={() => setIsEditing(false)}
        />
      ) : (
        <WriteupDisplay
          writeup={writeupData}
          user={user}
          isDraft
          publicationStatus={draft.publication_status}
          showVoting={false}
        />
      )}

      {/* Publish Modal */}
      {showPublishModal && (
        <PublishModal
          draft={draft}
          onSuccess={() => {
            // PublishModal handles redirect on success
          }}
          onClose={() => setShowPublishModal(false)}
        />
      )}
    </div>
  )
}

export default Draft
