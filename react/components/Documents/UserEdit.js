import React, { useState, useEffect, useCallback } from 'react'
import { useEditor, EditorContent } from '@tiptap/react'
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
  const [selectedBookmarks, setSelectedBookmarks] = useState(new Set())
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState(null)
  const [success, setSuccess] = useState(null)
  const [previewTrigger, setPreviewTrigger] = useState(0)

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
    }
  }, [data?.user, editor])

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

  const handleBookmarkToggle = (nodeId) => {
    setSelectedBookmarks(prev => {
      const newSet = new Set(prev)
      if (newSet.has(nodeId)) {
        newSet.delete(nodeId)
      } else {
        newSet.add(nodeId)
      }
      return newSet
    })
  }

  const handleCheckAll = () => {
    if (user.bookmarks && user.bookmarks.length > 0) {
      if (selectedBookmarks.size === user.bookmarks.length) {
        setSelectedBookmarks(new Set())
      } else {
        setSelectedBookmarks(new Set(user.bookmarks.map(b => b.node_id)))
      }
    }
  }

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
      if (selectedBookmarks.size > 0) {
        submitData.bookmark_remove = Array.from(selectedBookmarks)
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
        setSelectedBookmarks(new Set())
        setTimeout(() => {
          window.location.reload()
        }, 1500)
      } else {
        setError(result.error || 'Failed to update profile')
      }
    } catch (err) {
      setError(err.message || 'An error occurred while saving')
    } finally {
      setSaving(false)
    }
  }, [formData, removeImage, selectedBookmarks, user.node_id, getCurrentContent])

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

        {/* User image section */}
        {user.imgsrc && (
          <fieldset style={{ border: '1px solid #ddd', borderRadius: '6px', padding: '16px', marginBottom: '24px' }}>
            <legend style={{ fontWeight: 'bold', fontSize: '16px', color: '#38495e', padding: '0 8px' }}>Profile Image</legend>
            <img
              src={`/${user.imgsrc}`}
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

        {/* Bookmarks section */}
        {user.bookmarks && user.bookmarks.length > 0 && (
          <>
            <h2 style={{ marginBottom: '16px', marginTop: '32px', color: '#111111', borderBottom: '2px solid #38495e', paddingBottom: '8px' }}>
              Bookmarks
            </h2>

            <fieldset style={{ border: '1px solid #ddd', borderRadius: '6px', padding: '16px', marginBottom: '24px' }}>
              <legend style={{ fontWeight: 'bold', fontSize: '16px', color: '#38495e', padding: '0 8px' }}>Manage Bookmarks</legend>
              <p style={{ marginBottom: '12px', color: '#507898', fontSize: '13px' }}>
                Select bookmarks to remove from your list.
              </p>
              <button
                type="button"
                onClick={handleCheckAll}
                style={{
                  marginBottom: '12px',
                  padding: '6px 12px',
                  border: '1px solid #4060b0',
                  borderRadius: '4px',
                  backgroundColor: 'white',
                  color: '#4060b0',
                  cursor: 'pointer',
                  fontSize: '13px'
                }}
              >
                {selectedBookmarks.size === user.bookmarks.length ? 'Uncheck All' : 'Check All'}
              </button>
              <div style={{ maxHeight: '300px', overflow: 'auto', border: '1px solid #eee', borderRadius: '4px', padding: '8px' }}>
                {user.bookmarks.map((bookmark) => (
                  <label key={bookmark.node_id} style={{ display: 'flex', alignItems: 'center', gap: '8px', padding: '6px', cursor: 'pointer' }}>
                    <input
                      type="checkbox"
                      checked={selectedBookmarks.has(bookmark.node_id)}
                      onChange={() => handleBookmarkToggle(bookmark.node_id)}
                    />
                    <LinkNode nodeId={bookmark.node_id} title={bookmark.title} />
                  </label>
                ))}
              </div>
            </fieldset>
          </>
        )}

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
      </form>
    </div>
  )
}

export default UserEdit
