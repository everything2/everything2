import React, { useState, useEffect, useCallback } from 'react'
import { useEditor, EditorContent } from '@tiptap/react'
import {
  DndContext,
  closestCenter,
  KeyboardSensor,
  PointerSensor,
  useSensor,
  useSensors,
} from '@dnd-kit/core'
import {
  arrayMove,
  SortableContext,
  sortableKeyboardCoordinates,
  useSortable,
  verticalListSortingStrategy,
} from '@dnd-kit/sortable'
import { CSS } from '@dnd-kit/utilities'
import { getE2EditorExtensions } from '../Editor/useE2Editor'
import { convertToE2Syntax } from '../Editor/E2LinkExtension'
import { convertRawBracketsToEntities, convertEntitiesToRawBrackets } from '../Editor/RawBracketExtension'
import MenuBar from '../Editor/MenuBar'
import PreviewContent from '../Editor/PreviewContent'
import EditorModeToggle from '../Editor/EditorModeToggle'
import SettingsNavigation from '../SettingsNavigation'
import LinkNode from '../LinkNode'
import '../Editor/E2Editor.css'

/**
 * SortableBookmarkItem - Draggable bookmark item with remove button
 */
function SortableBookmarkItem({ id, title, onRemove }) {
  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({ id })

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    padding: '10px 12px',
    margin: '4px 0',
    backgroundColor: isDragging ? '#f0f0f0' : 'white',
    border: '1px solid #ddd',
    borderRadius: '4px',
    cursor: 'grab',
    userSelect: 'none',
    opacity: isDragging ? 0.5 : 1,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
  }

  return (
    <div ref={setNodeRef} style={style}>
      <div style={{ display: 'flex', alignItems: 'center', flex: 1 }} {...attributes} {...listeners}>
        <span style={{ marginRight: '10px', color: '#507898', fontSize: '14px' }}>☰</span>
        <LinkNode nodeId={id} title={title} />
      </div>
      <button
        onClick={(e) => {
          e.stopPropagation()
          onRemove(id)
        }}
        style={{
          padding: '4px 10px',
          fontSize: '14px',
          border: '1px solid #d9534f',
          borderRadius: '3px',
          backgroundColor: 'white',
          color: '#d9534f',
          cursor: 'pointer',
          marginLeft: '12px',
        }}
        title="Remove bookmark"
      >
        ×
      </button>
    </div>
  )
}

/**
 * UserEdit - Edit page for user nodes (homenodes)
 *
 * Migrated from Everything::Delegation::htmlpage::classic_user_edit_page
 * Uses TipTap editor with live preview for the bio field.
 * Uses shared EditorModeToggle component for UI consistency.
 *
 * This page can be used by:
 * - Users editing their own profile
 * - Admins editing other users' profiles
 */

// Get initial editor mode from localStorage
const getInitialEditorMode = () => {
  try {
    const stored = localStorage.getItem('e2_editor_mode')
    if (stored === 'html') return 'html'
  } catch (e) {
    // localStorage may not be available
  }
  return 'rich'
}

const UserEdit = ({ data, e2 }) => {
  // Form state
  const [formData, setFormData] = useState({
    realname: '',
    email: '',
    passwd: '',
    user_doctext: '',
    mission: '',
    specialties: '',
    employment: '',
    motto: ''
  })
  const [confirmPasswd, setConfirmPasswd] = useState('')
  const [removeImage, setRemoveImage] = useState(false)
  const [selectedFile, setSelectedFile] = useState(null)
  const [uploadStatus, setUploadStatus] = useState(null)
  const [uploading, setUploading] = useState(false)
  const [bookmarks, setBookmarks] = useState([])
  const [removedBookmarks, setRemovedBookmarks] = useState(new Set())
  const [savedBookmarkOrder, setSavedBookmarkOrder] = useState(null) // Track last saved order
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState(null)
  const [success, setSuccess] = useState(null)
  const [previewTrigger, setPreviewTrigger] = useState(0)
  const [isDirty, setIsDirty] = useState(false)

  // Check if passwords match (both empty counts as matching)
  const passwordsMatch = formData.passwd === confirmPasswd
  const hasPasswordInput = formData.passwd.length > 0 || confirmPasswd.length > 0

  // Editor mode state - uses localStorage for persistence
  const [editorMode, setEditorMode] = useState(getInitialEditorMode)
  const [htmlContent, setHtmlContent] = useState('')

  // Initialize TipTap editor
  const editor = useEditor({
    extensions: getE2EditorExtensions(),
    content: '',
    onUpdate: () => {
      setPreviewTrigger(prev => prev + 1)
    }
  })

  // Drag-and-drop sensors for bookmark reordering
  const sensors = useSensors(
    useSensor(PointerSensor),
    useSensor(KeyboardSensor, {
      coordinateGetter: sortableKeyboardCoordinates,
    })
  )

  // Initialize form data from user profile
  useEffect(() => {
    if (data?.user) {
      const doctext = data.user.doctext || ''
      setFormData({
        realname: data.user.realname || '',
        email: data.user.email || '',
        passwd: '',
        user_doctext: doctext,
        mission: data.user.mission || '',
        specialties: data.user.specialties || '',
        employment: data.user.employment || '',
        motto: data.user.motto || ''
      })

      // Set editor content (both rich and HTML modes)
      if (editor) {
        const withBrackets = convertEntitiesToRawBrackets(doctext)
        editor.commands.setContent(withBrackets)
      }
      setHtmlContent(doctext)

      // Initialize bookmarks array
      if (data.user.bookmarks && data.user.bookmarks.length > 0) {
        setBookmarks(data.user.bookmarks)
      }
    }
  }, [data?.user, editor])

  // Track if form has unsaved changes
  useEffect(() => {
    if (!data?.user) return

    const originalData = {
      realname: data.user.realname || '',
      email: data.user.email || '',
      passwd: '',
      mission: data.user.mission || '',
      specialties: data.user.specialties || '',
      employment: data.user.employment || '',
      motto: data.user.motto || ''
    }

    const formChanged =
      formData.realname !== originalData.realname ||
      formData.email !== originalData.email ||
      formData.passwd !== '' ||
      formData.mission !== originalData.mission ||
      formData.specialties !== originalData.specialties ||
      formData.employment !== originalData.employment ||
      formData.motto !== originalData.motto ||
      removeImage

    // Check if bookmarks changed (removed or reordered)
    // Use savedBookmarkOrder as baseline if we've saved, otherwise use original data
    const baselineBookmarkIds = savedBookmarkOrder || (data.user.bookmarks || []).map(b => b.node_id)
    const currentBookmarkIds = bookmarks.map(b => b.node_id)
    const bookmarksChanged = removedBookmarks.size > 0 ||
      JSON.stringify(baselineBookmarkIds) !== JSON.stringify(currentBookmarkIds)

    // Also check if bio content changed (compare to original doctext)
    const originalDoctext = data.user.doctext || ''
    const currentBioContent = editorMode === 'html' ? htmlContent : (editor ? editor.getHTML() : '')
    const bioChanged = currentBioContent !== '' && currentBioContent !== '<p></p>' &&
      currentBioContent !== convertEntitiesToRawBrackets(originalDoctext)

    setIsDirty(formChanged || bookmarksChanged || bioChanged)
  }, [formData, removeImage, bookmarks, removedBookmarks, savedBookmarkOrder, htmlContent, editor, editorMode, data?.user])

  // Warn about unsaved changes on navigation
  useEffect(() => {
    const handleBeforeUnload = (e) => {
      if (isDirty) {
        e.preventDefault()
        e.returnValue = ''
      }
    }

    window.addEventListener('beforeunload', handleBeforeUnload)
    return () => window.removeEventListener('beforeunload', handleBeforeUnload)
  }, [isDirty])

  if (!data || !data.user) return null

  const { user, viewer, can_have_image } = data

  // Determine if this is the user editing their own profile
  // Use == for comparison since viewer.node_id may be string while user.node_id is number
  const isOwnProfile = viewer && user && String(viewer.node_id) === String(user.node_id)

  const handleInputChange = (e) => {
    const { name, value } = e.target
    setFormData(prev => ({
      ...prev,
      [name]: value
    }))
  }

  // Handle HTML textarea changes
  const onHtmlChange = (e) => {
    setHtmlContent(e.target.value)
    setPreviewTrigger(prev => prev + 1)
  }

  // Toggle between Rich and HTML modes
  const toggleMode = useCallback(() => {
    const newMode = editorMode === 'rich' ? 'html' : 'rich'

    if (editorMode === 'rich' && editor) {
      // Switching to HTML mode - capture current rich content
      const html = editor.getHTML()
      const withEntities = convertRawBracketsToEntities(html)
      setHtmlContent(convertToE2Syntax(withEntities))
    } else if (editorMode === 'html' && editor) {
      // Switching to rich mode - load HTML content into editor
      const withBrackets = convertEntitiesToRawBrackets(htmlContent)
      editor.commands.setContent(withBrackets)
    }

    setEditorMode(newMode)

    // Save preference to localStorage
    try {
      localStorage.setItem('e2_editor_mode', newMode)
    } catch (e) {
      // localStorage may not be available
    }
  }, [editor, editorMode, htmlContent])

  // Get current bio content for submission
  const getCurrentContent = useCallback(() => {
    if (editorMode === 'html') {
      return htmlContent
    }
    if (editor) {
      const html = editor.getHTML()
      const withEntities = convertRawBracketsToEntities(html)
      return convertToE2Syntax(withEntities)
    }
    return ''
  }, [editor, editorMode, htmlContent])

  // Handle bookmark removal
  const handleRemoveBookmark = useCallback((nodeId) => {
    setBookmarks(prev => prev.filter(b => b.node_id !== nodeId))
    setRemovedBookmarks(prev => new Set([...prev, nodeId]))
  }, [])

  // Handle drag end for bookmark reordering
  const handleBookmarkDragEnd = useCallback((event) => {
    const { active, over } = event

    if (active.id !== over.id) {
      setBookmarks((items) => {
        const oldIndex = items.findIndex((item) => item.node_id === active.id)
        const newIndex = items.findIndex((item) => item.node_id === over.id)
        return arrayMove(items, oldIndex, newIndex)
      })
    }
  }, [])

  // Handle file selection for image upload
  const handleFileSelect = useCallback((e) => {
    const file = e.target.files[0]
    if (file) {
      // Validate file type
      if (!file.type.match(/^image\/(jpeg|jpg|gif|png)$/i)) {
        setUploadStatus({ type: 'error', message: 'Only JPEG, GIF, and PNG images are allowed' })
        setSelectedFile(null)
        return
      }
      // Validate file size (800KB for regular users)
      const maxSize = 800 * 1024
      if (file.size > maxSize) {
        setUploadStatus({ type: 'error', message: `Image is too large. Maximum size is ${maxSize / 1024}KB` })
        setSelectedFile(null)
        return
      }
      setSelectedFile(file)
      setUploadStatus(null)
    }
  }, [])

  // Handle image upload
  const handleImageUpload = useCallback(async () => {
    if (!selectedFile) return

    setUploading(true)
    setUploadStatus(null)

    try {
      const formData = new FormData()
      formData.append('imgsrc_file', selectedFile)

      const response = await fetch('/api/user/upload-image', {
        method: 'POST',
        credentials: 'same-origin',
        body: formData
      })

      const result = await response.json()

      if (result.success) {
        setUploadStatus({ type: 'success', message: result.message })
        setSelectedFile(null)
        // Reload the page to show the new image
        window.location.reload()
      } else {
        setUploadStatus({ type: 'error', message: result.error || 'Upload failed' })
      }
    } catch (err) {
      setUploadStatus({ type: 'error', message: err.message || 'An error occurred during upload' })
    } finally {
      setUploading(false)
    }
  }, [selectedFile])

  const handleSubmit = useCallback(async (e) => {
    e.preventDefault()
    setSaving(true)
    setError(null)
    setSuccess(null)

    try {
      // Get current bio content from editor using shared hook
      const bioContent = getCurrentContent()

      // Build JSON data for submission
      const submitData = {
        node_id: user.node_id,
        ...formData,
        user_doctext: bioContent
      }

      // Add image removal flag
      if (removeImage) {
        submitData.remove_image = true
      }

      // Add bookmarks to remove
      if (removedBookmarks.size > 0) {
        submitData.bookmark_remove = Array.from(removedBookmarks)
      }

      // Add bookmark order (array of node_ids in desired order)
      const originalBookmarkIds = (data.user.bookmarks || []).map(b => b.node_id)
      const currentBookmarkIds = bookmarks.map(b => b.node_id)
      if (JSON.stringify(originalBookmarkIds) !== JSON.stringify(currentBookmarkIds)) {
        submitData.bookmark_order = currentBookmarkIds
      }

      // Submit via API
      const response = await fetch('/api/user/edit', {
        method: 'POST',
        credentials: 'same-origin',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(submitData)
      })

      const result = await response.json()

      if (result.success) {
        setSuccess('Profile updated successfully!')
        setRemovedBookmarks(new Set())
        // Update the saved bookmark order baseline so dirty detection uses the new order
        setSavedBookmarkOrder(bookmarks.map(b => b.node_id))
        setIsDirty(false)
      } else {
        setError(result.error || 'Failed to update profile')
      }
    } catch (err) {
      setError(err.message || 'An error occurred while saving')
    } finally {
      setSaving(false)
    }
  }, [formData, removeImage, removedBookmarks, bookmarks, user.node_id, getCurrentContent, data.user.bookmarks])

  // Handle tab navigation - navigates to Settings page with hash
  const handleTabChange = useCallback((tab) => {
    if (tab === 'profile') {
      // Already on profile edit, do nothing
      return
    }
    // Navigate to Settings page with the selected tab
    window.location.href = `/node/superdoc/Settings#${tab}`
  }, [])

  return (
    <div className="user-edit" style={{ padding: '20px', maxWidth: '900px', margin: '0 auto' }}>
      <h1 style={{ marginBottom: '20px', color: '#111111' }}>Settings</h1>

      {/* Save button and status - matches Settings layout */}
      <div style={{
        marginBottom: '20px',
        paddingBottom: '20px',
        borderBottom: '1px solid #ddd',
        display: 'flex',
        alignItems: 'center',
        gap: '12px'
      }}>
        <button
          type="submit"
          form="profile-form"
          disabled={saving || (hasPasswordInput && !passwordsMatch)}
          style={{
            padding: '10px 24px',
            backgroundColor: (saving || (hasPasswordInput && !passwordsMatch)) ? '#ccc' : '#4060b0',
            color: 'white',
            border: 'none',
            borderRadius: '4px',
            cursor: (saving || (hasPasswordInput && !passwordsMatch)) ? 'not-allowed' : 'pointer',
            fontWeight: 'bold'
          }}
        >
          {saving ? 'Saving...' : 'Save Changes'}
        </button>

        {hasPasswordInput && !passwordsMatch && (
          <span style={{ color: '#d9534f', fontSize: '14px' }}>
            Passwords must match to save
          </span>
        )}

        {success && (
          <span style={{ color: '#3bb5c3', fontSize: '14px', fontWeight: 'bold' }}>
            ✓ {success}
          </span>
        )}

        {error && (
          <span style={{ color: '#d9534f', fontSize: '14px' }}>
            Error: {error}
          </span>
        )}

        {isDirty && !saving && !success && (
          <span style={{ color: '#507898', fontSize: '14px' }}>
            You have unsaved changes
          </span>
        )}
      </div>

      {/* Tab-style navigation - shared component */}
      {/* Only show full navigation when editing own profile, otherwise just show profile edit header */}
      {isOwnProfile ? (
        <SettingsNavigation
          activeTab="profile"
          onTabChange={handleTabChange}
          username={user.title}
          showAdminTab={Boolean(viewer?.is_editor)}
        />
      ) : (
        <div style={{
          borderBottom: '1px solid #ddd',
          marginBottom: '20px',
          paddingBottom: '10px'
        }}>
          <span style={{ fontWeight: 'bold', color: '#4060b0' }}>
            Editing profile for: {user.title}
          </span>
        </div>
      )}

      <form id="profile-form" onSubmit={handleSubmit}>
        {/* Account Settings Section */}
        <h2 style={{ marginBottom: '16px', color: '#111111', borderBottom: '2px solid #38495e', paddingBottom: '8px' }}>
          Account Settings
        </h2>

        <fieldset style={{ border: '1px solid #ddd', borderRadius: '6px', padding: '16px', marginBottom: '24px' }}>
          <legend style={{ fontWeight: 'bold', fontSize: '16px', color: '#38495e', padding: '0 8px' }}>Credentials</legend>

          {/* Real name */}
          <div style={{ marginBottom: '16px' }}>
            <label style={{ display: 'block', marginBottom: '6px', fontWeight: 'bold' }}>
              Real Name
            </label>
            <input
              type="text"
              name="realname"
              value={formData.realname}
              onChange={handleInputChange}
              style={{
                width: '300px',
                padding: '8px 12px',
                border: '1px solid #ddd',
                borderRadius: '4px',
                fontSize: '14px'
              }}
            />
            {user.realname && (
              <div style={{ marginTop: '4px', fontSize: '13px', color: '#507898' }}>
                Currently: {user.realname}
              </div>
            )}
          </div>

          {/* Password */}
          <div style={{ marginBottom: '16px' }}>
            <label style={{ display: 'block', marginBottom: '6px', fontWeight: 'bold' }}>
              Change Password
            </label>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <input
                type="password"
                name="passwd"
                value={formData.passwd}
                onChange={handleInputChange}
                placeholder="Leave blank to keep current"
                style={{
                  width: '300px',
                  padding: '8px 12px',
                  border: `1px solid ${hasPasswordInput ? (passwordsMatch ? '#3bb5c3' : '#d9534f') : '#ddd'}`,
                  borderRadius: '4px',
                  fontSize: '14px'
                }}
              />
              {hasPasswordInput && (
                <span style={{ color: passwordsMatch ? '#3bb5c3' : '#d9534f', fontSize: '18px' }}>
                  {passwordsMatch ? '✓' : '✗'}
                </span>
              )}
            </div>
          </div>

          {/* Confirm Password */}
          <div style={{ marginBottom: '16px' }}>
            <label style={{ display: 'block', marginBottom: '6px', fontWeight: 'bold' }}>
              Confirm Password
            </label>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <input
                type="password"
                value={confirmPasswd}
                onChange={(e) => setConfirmPasswd(e.target.value)}
                placeholder="Re-enter new password"
                style={{
                  width: '300px',
                  padding: '8px 12px',
                  border: `1px solid ${hasPasswordInput ? (passwordsMatch ? '#3bb5c3' : '#d9534f') : '#ddd'}`,
                  borderRadius: '4px',
                  fontSize: '14px'
                }}
              />
              {hasPasswordInput && (
                <span style={{ color: passwordsMatch ? '#3bb5c3' : '#d9534f', fontSize: '18px' }}>
                  {passwordsMatch ? '✓' : '✗'}
                </span>
              )}
            </div>
            {hasPasswordInput && !passwordsMatch && (
              <div style={{ marginTop: '4px', fontSize: '13px', color: '#d9534f' }}>
                Passwords do not match
              </div>
            )}
          </div>

          {/* Email */}
          <div>
            <label style={{ display: 'block', marginBottom: '6px', fontWeight: 'bold' }}>
              Email Address
            </label>
            <input
              type="email"
              name="email"
              value={formData.email}
              onChange={handleInputChange}
              style={{
                width: '300px',
                padding: '8px 12px',
                border: '1px solid #ddd',
                borderRadius: '4px',
                fontSize: '14px'
              }}
            />
            {user.email && (
              <div style={{ marginTop: '4px', fontSize: '13px', color: '#507898' }}>
                Currently: {user.email}
              </div>
            )}
          </div>
        </fieldset>

        {/* User image section - show if user has image or can upload */}
        {(user.imgsrc || can_have_image) && (
          <fieldset style={{ border: '1px solid #ddd', borderRadius: '6px', padding: '16px', marginBottom: '24px' }}>
            <legend style={{ fontWeight: 'bold', fontSize: '16px', color: '#38495e', padding: '0 8px' }}>Profile Image</legend>

            {/* Show current image if exists */}
            {user.imgsrc && (
              <div style={{ marginBottom: '16px' }}>
                <img
                  src={`https://s3-us-west-2.amazonaws.com/hnimagew.everything2.com/${user.title.replace(/\W/g, '_')}`}
                  alt={`${user.title}'s image`}
                  style={{ maxWidth: '200px', maxHeight: '200px', display: 'block', marginBottom: '12px', borderRadius: '4px' }}
                />
                <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer' }}>
                  <input
                    type="checkbox"
                    checked={removeImage}
                    onChange={(e) => setRemoveImage(e.target.checked)}
                  />
                  <strong>Remove image</strong>
                </label>
              </div>
            )}

            {/* Upload new image section */}
            {can_have_image && (
              <div style={{ marginTop: user.imgsrc ? '16px' : 0, paddingTop: user.imgsrc ? '16px' : 0, borderTop: user.imgsrc ? '1px solid #ddd' : 'none' }}>
                <p style={{ marginBottom: '12px', color: '#507898', fontSize: '13px' }}>
                  Upload a new image. Only JPEG, GIF, and PNG files are allowed (max 800KB).
                  Large images will be automatically resized.
                </p>

                <div style={{ display: 'flex', alignItems: 'center', gap: '12px', flexWrap: 'wrap' }}>
                  <input
                    type="file"
                    accept="image/jpeg,image/jpg,image/gif,image/png"
                    onChange={handleFileSelect}
                    style={{ fontSize: '14px' }}
                  />

                  {selectedFile && (
                    <button
                      type="button"
                      onClick={handleImageUpload}
                      disabled={uploading}
                      style={{
                        padding: '8px 16px',
                        backgroundColor: uploading ? '#ccc' : '#4060b0',
                        color: 'white',
                        border: 'none',
                        borderRadius: '4px',
                        cursor: uploading ? 'not-allowed' : 'pointer',
                        fontWeight: 'bold',
                        fontSize: '14px'
                      }}
                    >
                      {uploading ? 'Uploading...' : 'Upload Image'}
                    </button>
                  )}
                </div>

                {selectedFile && (
                  <div style={{ marginTop: '8px', fontSize: '13px', color: '#507898' }}>
                    Selected: {selectedFile.name} ({Math.round(selectedFile.size / 1024)}KB)
                  </div>
                )}

                {uploadStatus && (
                  <div style={{
                    marginTop: '8px',
                    fontSize: '13px',
                    color: uploadStatus.type === 'error' ? '#d9534f' : '#3bb5c3',
                    fontWeight: uploadStatus.type === 'success' ? 'bold' : 'normal'
                  }}>
                    {uploadStatus.type === 'success' ? '✓ ' : ''}{uploadStatus.message}
                  </div>
                )}
              </div>
            )}

            {/* Show message for users who can't upload */}
            {!can_have_image && !user.imgsrc && (
              <p style={{ color: '#507898', fontSize: '13px', fontStyle: 'italic' }}>
                You must reach level 1 to upload a homenode image.
              </p>
            )}
          </fieldset>
        )}

        {/* Profile Information Section */}
        <h2 style={{ marginBottom: '16px', marginTop: '32px', color: '#111111', borderBottom: '2px solid #38495e', paddingBottom: '8px' }}>
          Profile Information
        </h2>

        <fieldset style={{ border: '1px solid #ddd', borderRadius: '6px', padding: '16px', marginBottom: '24px' }}>
          <legend style={{ fontWeight: 'bold', fontSize: '16px', color: '#38495e', padding: '0 8px' }}>About You</legend>

          {/* Mission drive */}
          <div style={{ marginBottom: '16px' }}>
            <label style={{ display: 'block', marginBottom: '6px', fontWeight: 'bold' }}>
              Mission drive within everything
            </label>
            <input
              type="text"
              name="mission"
              value={formData.mission}
              onChange={handleInputChange}
              style={{
                width: '100%',
                padding: '8px 12px',
                border: '1px solid #ddd',
                borderRadius: '4px',
                fontSize: '14px'
              }}
            />
          </div>

          {/* Specialties */}
          <div style={{ marginBottom: '16px' }}>
            <label style={{ display: 'block', marginBottom: '6px', fontWeight: 'bold' }}>
              Specialties
            </label>
            <input
              type="text"
              name="specialties"
              value={formData.specialties}
              onChange={handleInputChange}
              style={{
                width: '100%',
                padding: '8px 12px',
                border: '1px solid #ddd',
                borderRadius: '4px',
                fontSize: '14px'
              }}
            />
          </div>

          {/* School/Company */}
          <div style={{ marginBottom: '16px' }}>
            <label style={{ display: 'block', marginBottom: '6px', fontWeight: 'bold' }}>
              School/Company
            </label>
            <input
              type="text"
              name="employment"
              value={formData.employment}
              onChange={handleInputChange}
              style={{
                width: '100%',
                padding: '8px 12px',
                border: '1px solid #ddd',
                borderRadius: '4px',
                fontSize: '14px'
              }}
            />
          </div>

          {/* Motto */}
          <div>
            <label style={{ display: 'block', marginBottom: '6px', fontWeight: 'bold' }}>
              Motto
            </label>
            <input
              type="text"
              name="motto"
              value={formData.motto}
              onChange={handleInputChange}
              style={{
                width: '100%',
                padding: '8px 12px',
                border: '1px solid #ddd',
                borderRadius: '4px',
                fontSize: '14px'
              }}
            />
          </div>
        </fieldset>

        {/* User bio with TipTap editor */}
        <h2 style={{ marginBottom: '16px', marginTop: '32px', color: '#111111', borderBottom: '2px solid #38495e', paddingBottom: '8px' }}>
          Bio
        </h2>

        <fieldset style={{ border: '1px solid #ddd', borderRadius: '6px', padding: '16px', marginBottom: '24px' }}>
          <legend style={{ fontWeight: 'bold', fontSize: '16px', color: '#38495e', padding: '0 8px' }}>Your Bio</legend>
          <p style={{ marginBottom: '12px', color: '#507898', fontSize: '13px' }}>
            Write about yourself. This will appear on your homenode for other users to see.
          </p>

          {/* Rich/HTML mode toggle - using shared component */}
          <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: '12px' }}>
            <EditorModeToggle mode={editorMode} onToggle={toggleMode} />
          </div>

          {/* Editor */}
          {editorMode === 'rich' ? (
            <div className="e2-editor-container" style={{ border: '1px solid #ddd', borderRadius: '4px' }}>
              <MenuBar editor={editor} />
              <EditorContent
                editor={editor}
                className="e2-editor-content"
                style={{
                  minHeight: '200px',
                  padding: '10px',
                  backgroundColor: '#fff'
                }}
              />
            </div>
          ) : (
            <textarea
              value={htmlContent}
              onChange={onHtmlChange}
              rows={15}
              style={{
                width: '100%',
                padding: '10px',
                fontFamily: 'monospace',
                fontSize: '13px',
                border: '1px solid #ddd',
                borderRadius: '4px',
                resize: 'vertical'
              }}
            />
          )}

          {/* Live Preview */}
          <div style={{ marginTop: '16px' }}>
            <p style={{ fontSize: '13px', color: '#507898', marginBottom: '8px' }}>
              <strong>Preview:</strong>
            </p>
            <PreviewContent
              editor={editor}
              editorMode={editorMode}
              htmlContent={htmlContent}
              previewTrigger={previewTrigger}
            />
          </div>
        </fieldset>

        {/* Bookmarks section - below bio */}
        {bookmarks.length > 0 && (
          <>
            <h2 style={{ marginBottom: '16px', marginTop: '32px', color: '#111111', borderBottom: '2px solid #38495e', paddingBottom: '8px' }}>
              Bookmarks
            </h2>

            <fieldset style={{ border: '1px solid #ddd', borderRadius: '6px', padding: '16px', marginBottom: '24px' }}>
              <legend style={{ fontWeight: 'bold', fontSize: '16px', color: '#38495e', padding: '0 8px' }}>Manage Bookmarks</legend>
              <p style={{ marginBottom: '12px', color: '#507898', fontSize: '13px' }}>
                Drag to reorder your bookmarks, or click × to remove. Changes are saved when you click "Save Changes".
              </p>

              <DndContext
                sensors={sensors}
                collisionDetection={closestCenter}
                onDragEnd={handleBookmarkDragEnd}
              >
                <SortableContext
                  items={bookmarks.map(b => b.node_id)}
                  strategy={verticalListSortingStrategy}
                >
                  <div style={{ maxHeight: '400px', overflow: 'auto' }}>
                    {bookmarks.map((bookmark) => (
                      <SortableBookmarkItem
                        key={bookmark.node_id}
                        id={bookmark.node_id}
                        title={bookmark.title}
                        onRemove={handleRemoveBookmark}
                      />
                    ))}
                  </div>
                </SortableContext>
              </DndContext>

              {bookmarks.length === 0 && (
                <p style={{ color: '#507898', fontStyle: 'italic' }}>
                  No bookmarks remaining.
                </p>
              )}
            </fieldset>
          </>
        )}
      </form>
    </div>
  )
}

export default UserEdit
