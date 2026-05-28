import React, { useState } from 'react'
import WriteupDisplay from '../WriteupDisplay'
import InlineWriteupEditor from '../InlineWriteupEditor'
import PublishModal from './PublishModal'
import DraftAdminModal from '../DraftAdminModal'
import LinkNode from '../LinkNode'
import { FaEdit, FaTrash, FaPaperPlane, FaCheckCircle } from 'react-icons/fa'

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
 * - Admin gear menu for removed drafts (editors/admins) - opens DraftAdminModal
 */

const Draft = ({ data }) => {
  const [isEditing, setIsEditing] = useState(false)
  const [currentDoctext, setCurrentDoctext] = useState(null)
  const [isDeleting, setIsDeleting] = useState(false)
  const [deleteError, setDeleteError] = useState(null)
  const [showPublishModal, setShowPublishModal] = useState(false)
  const [adminModalOpen, setAdminModalOpen] = useState(false)
  const [isMarkingReviewed, setIsMarkingReviewed] = useState(false)
  const [reviewError, setReviewError] = useState(null)
  const [reviewStatusOverride, setReviewStatusOverride] = useState(null)

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
  const isEditor = user?.is_editor
  const isAdmin = user?.is_admin
  const authorName = draft.author?.title || 'Unknown'
  // Effective status reflects any client-side mark-reviewed action so the
  // button hides immediately on success without needing a full page reload.
  const effectiveStatus = reviewStatusOverride || draft.publication_status
  const isRemoved = effectiveStatus === 'removed'
  const isInReview = effectiveStatus === 'review'
  // Editors/admins can use admin tools on removed drafts
  const showAdminTools = isRemoved && (isEditor || isAdmin)
  // Editors (not just the author) can mark a draft reviewed when it's in
  // the 'review' publication status. Mirrors the For Review nodelet
  // visibility — same audience, same gate.
  const showMarkReviewed = isInReview && isEditor

  const handleMarkReviewed = async () => {
    if (isMarkingReviewed) return
    setIsMarkingReviewed(true)
    setReviewError(null)
    try {
      const response = await fetch(`/api/drafts/${draft.node_id}/mark_reviewed`, {
        method: 'POST',
        credentials: 'include',
        headers: { 'Content-Type': 'application/json' }
      })
      const result = await response.json()
      if (result.success) {
        // Hide the button locally; the server has already moved status to
        // 'private' and dropped the draft off the For Review nodelet.
        setReviewStatusOverride(result.status || 'private')
      } else {
        setReviewError(result.message || result.error || 'Failed to mark reviewed')
      }
    } catch (err) {
      setReviewError(err.message)
    } finally {
      setIsMarkingReviewed(false)
    }
  }

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
      {/* Toolbar - show if user can edit or there's an editor-only action.
          Buttons use the same .e2-action-chip class as the e2node Editor
          Tools / Bookmark / Cool chips so all top-of-page actions read as a
          single labelled affordance row instead of a mix of icon-only buttons
          and chip-with-label buttons. */}
      {(Boolean(canEdit) || showMarkReviewed) && !isEditing && (
        <div className="draft-page__toolbar">
          {Boolean(canEdit) && (
            <button
              onClick={() => setIsEditing(true)}
              title={isAuthor ? 'Edit your draft' : `Edit ${authorName}'s draft`}
              className="e2-action-chip"
            >
              <FaEdit />
              <span className="e2-action-chip__label">Edit</span>
            </button>
          )}
          {Boolean(isAuthor) && !isRemoved && (
            <>
              <button
                onClick={() => setShowPublishModal(true)}
                title="Publish this draft"
                className="e2-action-chip"
              >
                <FaPaperPlane />
                <span className="e2-action-chip__label">Publish</span>
              </button>
              <button
                onClick={handleDelete}
                disabled={isDeleting}
                title="Delete this draft"
                className="e2-action-chip"
              >
                <FaTrash />
                <span className="e2-action-chip__label">{isDeleting ? 'Deleting…' : 'Delete'}</span>
              </button>
            </>
          )}
          {showMarkReviewed && (
            <button
              onClick={handleMarkReviewed}
              disabled={isMarkingReviewed}
              title="Mark this draft as reviewed (drops it from the For Review nodelet and returns it to private)"
              className="e2-action-chip"
            >
              <FaCheckCircle />
              <span className="e2-action-chip__label">{isMarkingReviewed ? 'Marking…' : 'Mark Reviewed'}</span>
            </button>
          )}
        </div>
      )}

      {/* Delete error message */}
      {deleteError && (
        <div className="draft-page__error">
          Error: {deleteError}
        </div>
      )}

      {/* Mark-reviewed error message */}
      {reviewError && (
        <div className="draft-page__error">
          Error: {reviewError}
        </div>
      )}

      {/* Parent e2node info if linked */}
      {!isEditing && draft.parent_e2node && (
        <div className="draft-page__meta-info">
          Draft for: <LinkNode nodeId={draft.parent_e2node.node_id} title={draft.parent_e2node.title} type="e2node" />
        </div>
      )}

      {/* Collaborators info if present */}
      {!isEditing && draft.collaborators && (
        <div className="draft-page__meta-info">
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
          showAdminToolsOverride={showAdminTools}
          onAdminGearClick={() => setAdminModalOpen(true)}
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

      {/* Admin Modal for editors/admins on removed drafts */}
      {showAdminTools && (
        <DraftAdminModal
          draft={draft}
          user={user}
          isOpen={adminModalOpen}
          onClose={() => setAdminModalOpen(false)}
        />
      )}
    </div>
  )
}

export default Draft
