import React, { useState, useEffect, useCallback, useMemo } from 'react'
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
import UserInteractionsManager from '../UserInteractions/UserInteractionsManager'
import FavoriteUsersManager from '../UserInteractions/FavoriteUsersManager'
import SettingsNavigation from '../SettingsNavigation'
import { getE2EditorExtensions } from '../Editor/useE2Editor'
import { convertToE2Syntax } from '../Editor/E2LinkExtension'
import { convertRawBracketsToEntities, convertEntitiesToRawBrackets } from '../Editor/RawBracketExtension'
import MenuBar from '../Editor/MenuBar'
import PreviewContent from '../Editor/PreviewContent'
import EditorModeToggle from '../Editor/EditorModeToggle'
import LinkNode from '../LinkNode'
import '../Editor/E2Editor.css'

// Maximum length for macros (from legacy system)
const MAX_MACRO_LENGTH = 768

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

/**
 * SortableNodeletItem - Draggable nodelet item component with remove button
 */
function SortableNodeletItem({ id, title, onRemove, onConfigure }) {
  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({ id })

  // Only transform/transition need inline styles (dynamic values from drag state)
  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    opacity: isDragging ? 0.5 : 1,
  }

  return (
    <div
      ref={setNodeRef}
      style={style}
      className={`settings-nodelet-item${isDragging ? ' dragging' : ''}`}
    >
      <div className="settings-nodelet-item-content" {...attributes} {...listeners}>
        <span className="settings-nodelet-item-handle">☰</span>
        <span>{title}</span>
      </div>
      <div className="settings-nodelet-item-actions">
        {onConfigure && (
          <button
            onClick={(e) => {
              e.stopPropagation()
              onConfigure(id, title)
            }}
            className="settings-btn-configure"
            title="Configure preferences"
          >
            ⚙️
          </button>
        )}
        <button
          onClick={(e) => {
            e.stopPropagation()
            onRemove(id)
          }}
          className="settings-btn-danger"
          title="Remove nodelet"
        >
          ×
        </button>
      </div>
    </div>
  )
}

/**
 * Settings - Unified settings interface
 */
// Get initial tab from URL hash
const getInitialTab = (defaultTab) => {
  if (typeof window !== 'undefined') {
    const hash = window.location.hash.replace('#', '')
    if (['settings', 'advanced', 'nodelets', 'notifications', 'admin', 'profile'].includes(hash)) {
      return hash
    }
  }
  return defaultTab || 'settings'
}

// Helper to get trytheme from URL (called once during initialization)
const getTryThemeFromUrl = (availableStylesheets) => {
  if (typeof window === 'undefined') return null
  const urlParams = new URLSearchParams(window.location.search)
  const tryThemeId = urlParams.get('trytheme')
  if (!tryThemeId) return null

  // Validate that the theme ID is in the available stylesheets
  const validTheme = (availableStylesheets || []).find(
    style => String(style.node_id) === tryThemeId
  )
  return validTheme ? tryThemeId : null
}

function Settings({ data }) {
  // Check for trytheme parameter before initializing state
  const initialTryTheme = useMemo(() => getTryThemeFromUrl(data.availableStylesheets), [])

  const [activeTab, setActiveTab] = useState(() => {
    // If we have a valid trytheme, start on advanced tab
    if (initialTryTheme) return 'advanced'
    return getInitialTab(data.defaultTab)
  })
  const [isDirty, setIsDirty] = useState(false)

  // Update URL hash when tab changes (for bookmarkable tabs)
  const handleTabChange = useCallback((tab) => {
    setActiveTab(tab)
    if (typeof window !== 'undefined') {
      window.history.replaceState(null, '', `#${tab}`)
    }
  }, [])
  const [isSaving, setIsSaving] = useState(false)
  const [saveError, setSaveError] = useState(null)
  const [saveSuccess, setSaveSuccess] = useState(false)

  // Settings preferences state (Tab 1)
  // If trytheme parameter was provided, override userstyle
  const [settingsPrefs, setSettingsPrefs] = useState(() => {
    const prefs = data.settingsPreferences || {}
    if (initialTryTheme) {
      return { ...prefs, userstyle: initialTryTheme }
    }
    return prefs
  })

  // Handle trytheme: apply CSS and clean up URL after mount
  useEffect(() => {
    if (!initialTryTheme) return

    // Apply the theme CSS immediately for preview
    const zenSheet = document.getElementById('zensheet')
    if (zenSheet) {
      zenSheet.href = `/css/${initialTryTheme}.css`
    }

    // Clean up the URL to remove the trytheme parameter
    const urlParams = new URLSearchParams(window.location.search)
    urlParams.delete('trytheme')
    const newUrl = urlParams.toString()
      ? `${window.location.pathname}?${urlParams.toString()}#advanced`
      : `${window.location.pathname}#advanced`
    window.history.replaceState(null, '', newUrl)
  }, [initialTryTheme])

  // Advanced preferences state (Tab 2)
  const [advancedPrefs, setAdvancedPrefs] = useState(data.advancedPreferences || {})

  // Nodelet order state
  const [nodelets, setNodelets] = useState(data.nodelets || [])

  // Nodelet configuration state
  const [configuringNodelet, setConfiguringNodelet] = useState(null)

  // Blocked users state
  const [blockedUsers] = useState(data.blockedUsers || [])

  // Favorite users state
  const [favoriteUsers] = useState(data.favoriteUsers || [])

  // Nodelet-specific settings state
  const [nodeletSettings, setNodeletSettings] = useState(data.nodeletSettings || {})

  // Notification preferences state - initialize from data
  const [notificationPrefs, setNotificationPrefs] = useState(() => {
    const prefs = {}
    if (data.notificationPreferences) {
      data.notificationPreferences.forEach(notif => {
        prefs[notif.node_id] = notif.enabled === 1
      })
    }
    return prefs
  })

  // Editor preferences state (Admin tab - editors only)
  const [editorPrefs, setEditorPrefs] = useState(data.editorPreferences || {})

  // Macros state (Admin tab - editors only)
  const [macros, setMacros] = useState(data.macros || [])

  // Profile tab state
  const [profileData, setProfileData] = useState(() => ({
    realname: data.profileData?.realname || '',
    email: data.profileData?.email || '',
    passwd: '',
    doctext: data.profileData?.doctext || '',
    mission: data.profileData?.mission || '',
    specialties: data.profileData?.specialties || '',
    employment: data.profileData?.employment || '',
    motto: data.profileData?.motto || ''
  }))
  const [confirmPasswd, setConfirmPasswd] = useState('')
  const [removeImage, setRemoveImage] = useState(false)
  const [selectedBookmarks, setSelectedBookmarks] = useState(new Set())
  const [previewTrigger, setPreviewTrigger] = useState(0)

  // Editor mode state - uses localStorage for persistence
  const [editorMode, setEditorMode] = useState(getInitialEditorMode)
  const [htmlContent, setHtmlContent] = useState(data.profileData?.doctext || '')

  // Check if passwords match (both empty counts as matching)
  const passwordsMatch = profileData.passwd === confirmPasswd
  const hasPasswordInput = profileData.passwd.length > 0 || confirmPasswd.length > 0

  // Initialize TipTap editor for bio
  const bioEditor = useEditor({
    extensions: getE2EditorExtensions(),
    content: '',
    onUpdate: () => {
      setPreviewTrigger(prev => prev + 1)
    }
  })

  // Set editor content when it's ready
  useEffect(() => {
    if (bioEditor && data.profileData?.doctext) {
      const withBrackets = convertEntitiesToRawBrackets(data.profileData.doctext)
      bioEditor.commands.setContent(withBrackets)
    }
  }, [bioEditor, data.profileData?.doctext])

  // Drag-and-drop sensors
  const sensors = useSensors(
    useSensor(PointerSensor),
    useSensor(KeyboardSensor, {
      coordinateGetter: sortableKeyboardCoordinates,
    })
  )

  // Get available nodelets (not currently in user's list, and exclude "Sign in" for logged-in users)
  const availableNodelets = (data.availableNodelets || []).filter(
    available => {
      // Exclude if already in user's list
      if (nodelets.some(current => current.node_id === available.node_id)) {
        return false
      }
      // Exclude "Sign in" nodelet for logged-in users
      if (available.title === 'Sign in') {
        return false
      }
      return true
    }
  )

  // Track if settings have changed
  useEffect(() => {
    const prefsChanged = JSON.stringify(settingsPrefs) !== JSON.stringify(data.settingsPreferences || {})
    const advancedPrefsChanged = JSON.stringify(advancedPrefs) !== JSON.stringify(data.advancedPreferences || {})
    const nodeletsChanged = JSON.stringify(nodelets) !== JSON.stringify(data.nodelets || [])

    // Check if notification preferences changed
    const originalNotifs = {}
    if (data.notificationPreferences) {
      data.notificationPreferences.forEach(notif => {
        originalNotifs[notif.node_id] = notif.enabled === 1
      })
    }
    const notifsChanged = JSON.stringify(notificationPrefs) !== JSON.stringify(originalNotifs)

    // Check if nodelet settings changed
    const nodeletSettingsChanged = JSON.stringify(nodeletSettings) !== JSON.stringify(data.nodeletSettings || {})

    // Check if editor preferences changed (admin tab)
    const editorPrefsChanged = JSON.stringify(editorPrefs) !== JSON.stringify(data.editorPreferences || {})

    // Check if macros changed (admin tab)
    const macrosChanged = JSON.stringify(macros) !== JSON.stringify(data.macros || [])

    // Check if profile changed (profile tab)
    const originalProfile = {
      realname: data.profileData?.realname || '',
      email: data.profileData?.email || '',
      passwd: '',
      doctext: data.profileData?.doctext || '',
      mission: data.profileData?.mission || '',
      specialties: data.profileData?.specialties || '',
      employment: data.profileData?.employment || '',
      motto: data.profileData?.motto || ''
    }
    const profileChanged = JSON.stringify(profileData) !== JSON.stringify(originalProfile) ||
      removeImage ||
      selectedBookmarks.size > 0

    setIsDirty(prefsChanged || advancedPrefsChanged || nodeletsChanged || notifsChanged || nodeletSettingsChanged || editorPrefsChanged || macrosChanged || profileChanged)
  }, [settingsPrefs, advancedPrefs, nodelets, notificationPrefs, nodeletSettings, editorPrefs, macros, profileData, removeImage, selectedBookmarks, data.settingsPreferences, data.advancedPreferences, data.nodelets, data.notificationPreferences, data.nodeletSettings, data.editorPreferences, data.macros, data.profileData])

  // Handle preference toggle (for checkboxes)
  const handleTogglePref = useCallback((prefKey) => {
    setSettingsPrefs(prev => ({
      ...prev,
      [prefKey]: prev[prefKey] ? 0 : 1
    }))
  }, [])

  // Handle preference change (for selects/inputs)
  const handlePrefChange = useCallback((prefKey, value) => {
    setSettingsPrefs(prev => ({
      ...prev,
      [prefKey]: value
    }))
  }, [])

  // Handle advanced preference toggle (for checkboxes)
  const handleToggleAdvancedPref = useCallback((prefKey) => {
    setAdvancedPrefs(prev => ({
      ...prev,
      [prefKey]: prev[prefKey] ? 0 : 1
    }))
  }, [])

  // Handle advanced preference change (for selects/inputs)
  const handleAdvancedPrefChange = useCallback((prefKey, value) => {
    setAdvancedPrefs(prev => ({
      ...prev,
      [prefKey]: value
    }))
  }, [])

  // Handle editor preference toggle (Admin tab)
  const handleToggleEditorPref = useCallback((prefKey) => {
    setEditorPrefs(prev => ({
      ...prev,
      [prefKey]: prev[prefKey] ? 0 : 1
    }))
  }, [])

  // Handle macro enabled toggle (Admin tab)
  const handleToggleMacro = useCallback((macroName) => {
    setMacros(prev => prev.map(m =>
      m.name === macroName ? { ...m, enabled: m.enabled ? 0 : 1 } : m
    ))
  }, [])

  // Handle macro text change (Admin tab)
  const handleMacroTextChange = useCallback((macroName, newText) => {
    setMacros(prev => prev.map(m =>
      m.name === macroName ? { ...m, text: newText } : m
    ))
  }, [])

  // Profile tab handlers
  const handleProfileInputChange = useCallback((e) => {
    const { name, value } = e.target
    setProfileData(prev => ({
      ...prev,
      [name]: value
    }))
  }, [])

  const handleHtmlChange = useCallback((e) => {
    setHtmlContent(e.target.value)
    setPreviewTrigger(prev => prev + 1)
  }, [])

  const toggleEditorMode = useCallback(() => {
    const newMode = editorMode === 'rich' ? 'html' : 'rich'

    if (editorMode === 'rich' && bioEditor) {
      // Switching to HTML mode - capture current rich content
      const html = bioEditor.getHTML()
      const withEntities = convertRawBracketsToEntities(html)
      setHtmlContent(convertToE2Syntax(withEntities))
    } else if (editorMode === 'html' && bioEditor) {
      // Switching to rich mode - load HTML content into editor
      const withBrackets = convertEntitiesToRawBrackets(htmlContent)
      bioEditor.commands.setContent(withBrackets)
    }

    setEditorMode(newMode)

    // Save preference to localStorage
    try {
      localStorage.setItem('e2_editor_mode', newMode)
    } catch (e) {
      // localStorage may not be available
    }
  }, [bioEditor, editorMode, htmlContent])

  const getCurrentBioContent = useCallback(() => {
    if (editorMode === 'html') {
      return htmlContent
    }
    if (bioEditor) {
      const html = bioEditor.getHTML()
      const withEntities = convertRawBracketsToEntities(html)
      return convertToE2Syntax(withEntities)
    }
    return ''
  }, [bioEditor, editorMode, htmlContent])

  const handleBookmarkToggle = useCallback((nodeId) => {
    setSelectedBookmarks(prev => {
      const newSet = new Set(prev)
      if (newSet.has(nodeId)) {
        newSet.delete(nodeId)
      } else {
        newSet.add(nodeId)
      }
      return newSet
    })
  }, [])

  const handleCheckAllBookmarks = useCallback(() => {
    const bookmarks = data.bookmarks || []
    if (selectedBookmarks.size === bookmarks.length) {
      setSelectedBookmarks(new Set())
    } else {
      setSelectedBookmarks(new Set(bookmarks.map(b => b.node_id)))
    }
  }, [data.bookmarks, selectedBookmarks.size])

  // Handle drag end for nodelets
  const handleDragEnd = useCallback((event) => {
    const { active, over } = event

    if (active.id !== over.id) {
      setNodelets((items) => {
        const oldIndex = items.findIndex((item) => item.node_id === active.id)
        const newIndex = items.findIndex((item) => item.node_id === over.id)
        return arrayMove(items, oldIndex, newIndex)
      })
    }
  }, [])

  // Handle adding a nodelet
  const handleAddNodelet = useCallback((nodelet) => {
    setNodelets(prev => [...prev, nodelet])
  }, [])

  // Handle removing a nodelet
  const handleRemoveNodelet = useCallback((nodeletId) => {
    setNodelets(prev => prev.filter(n => n.node_id !== nodeletId))
    // Clear configuration if removing the nodelet being configured
    if (configuringNodelet && configuringNodelet.node_id === nodeletId) {
      setConfiguringNodelet(null)
    }
  }, [configuringNodelet])

  // Handle configure nodelet
  const handleConfigureNodelet = useCallback((nodeletId, title) => {
    setConfiguringNodelet({ node_id: nodeletId, title })
  }, [])

  // Determine if a nodelet has configuration options
  const hasConfiguration = useCallback((title) => {
    // Nodelets that have configuration preferences
    // Note: Notifications config is now in its own dedicated tab
    const configurableNodelets = ['New Writeups']
    return configurableNodelets.includes(title)
  }, [])


  // Handle nodelet-specific setting change
  const handleNodeletSettingChange = useCallback((nodeletId, settingKey, value) => {
    setNodeletSettings(prev => ({
      ...prev,
      [nodeletId]: {
        ...(prev[nodeletId] || {}),
        [settingKey]: value
      }
    }))
  }, [])

  // Save all settings
  const handleSave = useCallback(async () => {
    setIsSaving(true)
    setSaveError(null)
    setSaveSuccess(false)

    try {
      // Save settings preferences
      const prefsToSave = {}
      Object.keys(settingsPrefs).forEach(key => {
        if (settingsPrefs[key] !== (data.settingsPreferences || {})[key]) {
          prefsToSave[key] = settingsPrefs[key]
        }
      })

      // Add advanced preferences to save
      Object.keys(advancedPrefs).forEach(key => {
        if (advancedPrefs[key] !== (data.advancedPreferences || {})[key]) {
          prefsToSave[key] = advancedPrefs[key]
        }
      })

      if (Object.keys(prefsToSave).length > 0) {
        const prefsResponse = await fetch('/api/preferences/set', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(prefsToSave)
        })

        const prefsResult = await prefsResponse.json()
        if (!prefsResponse.ok) {
          throw new Error(prefsResult.message || 'Failed to save preferences')
        }
      }

      // Save nodelet order if changed
      const originalNodeletIds = (data.nodelets || []).map(n => n.node_id)
      const currentNodeletIds = nodelets.map(n => n.node_id)

      if (JSON.stringify(originalNodeletIds) !== JSON.stringify(currentNodeletIds)) {
        const nodeletsResponse = await fetch('/api/nodelets', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ nodelet_ids: currentNodeletIds })
        })

        const nodeletsResult = await nodeletsResponse.json()
        if (!nodeletsResult.success) {
          throw new Error(nodeletsResult.message || 'Failed to save nodelet order')
        }
      }

      // Save notification preferences if changed
      const originalNotifs = {}
      if (data.notificationPreferences) {
        data.notificationPreferences.forEach(notif => {
          originalNotifs[notif.node_id] = notif.enabled === 1
        })
      }

      if (JSON.stringify(notificationPrefs) !== JSON.stringify(originalNotifs)) {
        // Convert boolean values to 1 for enabled notifications only
        const notifsToSave = {}
        Object.keys(notificationPrefs).forEach(notifId => {
          if (notificationPrefs[notifId]) {
            notifsToSave[notifId] = 1
          }
        })

        const notifsResponse = await fetch('/api/preferences/notifications', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ notifications: notifsToSave })
        })

        const notifsResult = await notifsResponse.json()
        if (!notifsResult.success) {
          throw new Error(notifsResult.message || 'Failed to save notification preferences')
        }
      }

      // Save nodelet-specific settings if changed
      if (JSON.stringify(nodeletSettings) !== JSON.stringify(data.nodeletSettings || {})) {
        const nodeletPrefsToSave = {}
        Object.keys(nodeletSettings).forEach(nodeletId => {
          const settings = nodeletSettings[nodeletId]
          Object.keys(settings).forEach(key => {
            nodeletPrefsToSave[key] = settings[key]
          })
        })

        if (Object.keys(nodeletPrefsToSave).length > 0) {
          const nodeletPrefsResponse = await fetch('/api/preferences/set', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(nodeletPrefsToSave)
          })

          const nodeletPrefsResult = await nodeletPrefsResponse.json()
          if (!nodeletPrefsResponse.ok) {
            throw new Error(nodeletPrefsResult.message || 'Failed to save nodelet preferences')
          }
        }
      }

      // Save admin settings (editor preferences + macros) if changed
      const editorPrefsChanged = JSON.stringify(editorPrefs) !== JSON.stringify(data.editorPreferences || {})
      const macrosChanged = JSON.stringify(macros) !== JSON.stringify(data.macros || [])

      if (editorPrefsChanged || macrosChanged) {
        // Build the admin settings payload
        const adminPayload = {
          settings: { ...editorPrefs },
          macros: {}
        }

        // Add macros to payload
        macros.forEach(macro => {
          if (macro.enabled) {
            // Convert curly braces to square brackets for storage
            let text = macro.text
            text = text.replace(/\{/g, '[')
            text = text.replace(/\}/g, ']')
            // Clean up line endings
            text = text.replace(/\r/g, '\n')
            text = text.replace(/\n+/g, '\n')
            // Limit length
            text = text.substring(0, MAX_MACRO_LENGTH)
            adminPayload.macros[macro.name] = text
          } else {
            adminPayload.macros[macro.name] = null // Will delete the macro
          }
        })

        const adminResponse = await fetch('/api/preferences/admin', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(adminPayload)
        })

        const adminResult = await adminResponse.json()
        if (!adminResult.success) {
          throw new Error(adminResult.error || 'Failed to save admin settings')
        }
      }

      // Save profile data if changed (profile tab)
      const originalProfile = {
        realname: data.profileData?.realname || '',
        email: data.profileData?.email || '',
        passwd: '',
        doctext: data.profileData?.doctext || '',
        mission: data.profileData?.mission || '',
        specialties: data.profileData?.specialties || '',
        employment: data.profileData?.employment || '',
        motto: data.profileData?.motto || ''
      }

      const profileChanged = JSON.stringify(profileData) !== JSON.stringify(originalProfile) ||
        removeImage ||
        selectedBookmarks.size > 0

      if (profileChanged) {
        // Validation: passwords must match if password is being changed
        if (hasPasswordInput && !passwordsMatch) {
          throw new Error('Passwords do not match')
        }

        const profilePayload = {
          node_id: data.currentUser?.node_id,
          realname: profileData.realname,
          email: profileData.email,
          user_doctext: getCurrentBioContent(),
          mission: profileData.mission,
          specialties: profileData.specialties,
          employment: profileData.employment,
          motto: profileData.motto
        }

        // Only include password if it's being changed
        if (profileData.passwd) {
          profilePayload.passwd = profileData.passwd
        }

        // Include image removal flag
        if (removeImage) {
          profilePayload.remove_image = true
        }

        // Include bookmarks to remove
        if (selectedBookmarks.size > 0) {
          profilePayload.bookmark_remove = Array.from(selectedBookmarks)
        }

        const profileResponse = await fetch('/api/user/edit', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(profilePayload)
        })

        const profileResult = await profileResponse.json()
        if (!profileResult.success) {
          throw new Error(profileResult.error || 'Failed to save profile')
        }

        // Reset password fields after successful save
        setProfileData(prev => ({ ...prev, passwd: '' }))
        setConfirmPasswd('')
        setRemoveImage(false)
        setSelectedBookmarks(new Set())
      }

      setSaveSuccess(true)
      setIsDirty(false)

      // Clear success message after 3 seconds
      setTimeout(() => setSaveSuccess(false), 3000)
    } catch (err) {
      setSaveError(err.message)
    } finally {
      setIsSaving(false)
    }
  }, [settingsPrefs, advancedPrefs, nodelets, notificationPrefs, nodeletSettings, editorPrefs, macros, profileData, removeImage, selectedBookmarks, hasPasswordInput, passwordsMatch, getCurrentBioContent, data.settingsPreferences, data.advancedPreferences, data.nodelets, data.notificationPreferences, data.nodeletSettings, data.editorPreferences, data.macros, data.profileData, data.currentUser])

  // Warn about unsaved changes
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

  if (data.error === 'guest') {
    return (
      <div className="settings-guest-message">
        <p>{data.message}</p>
      </div>
    )
  }

  return (
    <div className="settings-page">
      <h1>Settings</h1>

      {/* Save button at top */}
      <div className="settings-save-area">
        <button
          onClick={handleSave}
          disabled={!isDirty || isSaving}
          className="settings-btn-primary"
        >
          {isSaving ? 'Saving...' : 'Save Changes'}
        </button>

        {isDirty && !isSaving && (
          <span className="settings-status-unsaved">
            You have unsaved changes
          </span>
        )}

        {saveSuccess && (
          <span className="settings-status-success">
            ✓ Settings saved successfully
          </span>
        )}

        {saveError && (
          <span className="settings-status-error">
            Error: {saveError}
          </span>
        )}
      </div>

      {/* Tab navigation - shared component */}
      <SettingsNavigation
        activeTab={activeTab}
        onTabChange={handleTabChange}
        username={data.currentUser?.title}
        showAdminTab={Boolean(data.isEditor)}
      />

      {/* Settings tab - Tab 1 from legacy settings function */}
      {activeTab === 'settings' && (
        <div>
          {/* Look and Feel Section */}
          <h2>Look and Feel</h2>

          {/* Confirmation Dialogs */}
          <fieldset className="settings-fieldset">
            <legend>Confirmation Dialogs</legend>

            <label className="settings-checkbox-label">
              <input
                type="checkbox"
                checked={settingsPrefs.votesafety === 1}
                onChange={() => handleTogglePref('votesafety')}
              />
              <strong>Ask for confirmation when voting</strong>
            </label>

            <label className="settings-checkbox-label">
              <input
                type="checkbox"
                checked={settingsPrefs.coolsafety === 1}
                onChange={() => handleTogglePref('coolsafety')}
              />
              <strong>Ask for confirmation when cooling writeups</strong>
            </label>
          </fieldset>

          {/* Your Writeups Section */}
          <h2 className="settings-section-header">Your Writeups</h2>

          {/* Writeup Hints */}
          <fieldset className="settings-fieldset">
            <legend>Writeup Hints</legend>
            <p className="settings-description">
              Check for some common mistakes made in creating or editing writeups.
            </p>

            <label className="settings-checkbox-label-compact">
              <input
                type="checkbox"
                checked={!(settingsPrefs.nohints === 1)}
                onChange={() => handleTogglePref('nohints')}
              />
              <strong>Show critical writeup hints</strong>
              <span className="settings-hint-inline">(recommended: on)</span>
            </label>

            <label className="settings-checkbox-label-compact">
              <input
                type="checkbox"
                checked={!(settingsPrefs.nohintSpelling === 1)}
                onChange={() => handleTogglePref('nohintSpelling')}
              />
              <strong>Check for common misspellings</strong>
              <span className="settings-hint-inline">(recommended: on)</span>
            </label>

            <label className="settings-checkbox-label-compact">
              <input
                type="checkbox"
                checked={!(settingsPrefs.nohintHTML === 1)}
                onChange={() => handleTogglePref('nohintHTML')}
              />
              <strong>Show HTML hints</strong>
              <span className="settings-hint-inline">(recommended: on)</span>
            </label>

            <label className="settings-checkbox-label-compact">
              <input
                type="checkbox"
                checked={settingsPrefs.hintXHTML === 1}
                onChange={() => handleTogglePref('hintXHTML')}
              />
              <strong>Show strict HTML hints</strong>
            </label>

            <label className="settings-checkbox-label-compact">
              <input
                type="checkbox"
                checked={settingsPrefs.hintSilly === 1}
                onChange={() => handleTogglePref('hintSilly')}
              />
              <strong>Show silly hints</strong>
            </label>
          </fieldset>

          {/* Other Users Section */}
          <h2 className="settings-section-header">Other Users</h2>

          <fieldset className="settings-fieldset">
            <legend>Other users' writeups</legend>

            <div className="settings-form-row">
              <label>Anonymous voting:</label>
              <select
                value={settingsPrefs.anonymousvote || 0}
                onChange={(e) => handlePrefChange('anonymousvote', parseInt(e.target.value, 10))}
                className="settings-select"
              >
                <option value="0">Always show author's username</option>
                <option value="1">Hide author until I vote</option>
                <option value="2">Hide name until I vote (still link)</option>
              </select>
            </div>
          </fieldset>

          <fieldset className="settings-fieldset">
            <legend>Favorite Users</legend>

            <FavoriteUsersManager
              initialFavorites={favoriteUsers}
              currentUser={data.currentUser}
            />
          </fieldset>

          <fieldset className="settings-fieldset">
            <legend>Blocked Users</legend>

            <UserInteractionsManager
              initialBlocked={blockedUsers}
              currentUser={data.currentUser}
            />

            <div className="settings-info-box">
              <p>
                <strong>Note:</strong> When you try to send a message to someone who has blocked you, you'll be notified immediately with an error message in the chatterbox or message compose window.
              </p>
            </div>
          </fieldset>
        </div>
      )}

      {/* Nodelets tab */}
      {activeTab === 'nodelets' && (
        <div>
          <p className="settings-intro">
            Nodelets are the boxes in your sidebar that provide quick access to different features.
            Drag and drop to rearrange them in your preferred order. Click <strong>Save Changes</strong> when you're done.
          </p>

          <h3>Active Nodelets</h3>
          <p className="settings-description">
            Drag to reorder, click × to remove, or ⚙️ to configure:
          </p>

          <DndContext
            sensors={sensors}
            collisionDetection={closestCenter}
            onDragEnd={handleDragEnd}
          >
            <SortableContext
              items={nodelets.map(n => n.node_id)}
              strategy={verticalListSortingStrategy}
            >
              <div style={{ marginBottom: '24px' }}>
                {nodelets.map((nodelet) => (
                  <SortableNodeletItem
                    key={nodelet.node_id}
                    id={nodelet.node_id}
                    title={nodelet.title}
                    onRemove={handleRemoveNodelet}
                    onConfigure={hasConfiguration(nodelet.title) ? handleConfigureNodelet : null}
                  />
                ))}
              </div>
            </SortableContext>
          </DndContext>

          {nodelets.length === 0 && (
            <p className="settings-hint" style={{ fontStyle: 'italic', marginBottom: '24px' }}>
              No nodelets active. Add some from the available nodelets below.
            </p>
          )}

          {/* Available nodelets to add */}
          {availableNodelets.length > 0 && (
            <div style={{ marginTop: '32px' }}>
              <h3>Available Nodelets</h3>
              <p className="settings-description">
                Click to add a nodelet to your sidebar:
              </p>
              <div className="settings-nodelets-grid">
                {availableNodelets.map((nodelet) => (
                  <button
                    key={nodelet.node_id}
                    onClick={() => handleAddNodelet(nodelet)}
                    className="settings-nodelet-add-btn"
                  >
                    + {nodelet.title}
                  </button>
                ))}
              </div>
            </div>
          )}

          {/* Nodelet configuration panel */}
          {configuringNodelet && (
            <div className="settings-config-panel">
              <div className="settings-config-panel-header">
                <h3>{configuringNodelet.title} Preferences</h3>
                <button
                  onClick={() => setConfiguringNodelet(null)}
                  className="settings-btn-secondary settings-btn-sm"
                >
                  Close
                </button>
              </div>

              {/* New Writeups nodelet preferences */}
              {configuringNodelet.title === 'New Writeups' && (
                <div>
                  <p className="settings-description">
                    Configure how many new writeups to display in the New Writeups nodelet.
                  </p>
                  <div style={{ marginLeft: '8px' }}>
                    <div className="settings-form-row">
                      <label>Number of new writeups to show:</label>
                      <select
                        value={nodeletSettings[configuringNodelet.node_id]?.num_newwus || 15}
                        onChange={(e) => handleNodeletSettingChange(configuringNodelet.node_id, 'num_newwus', parseInt(e.target.value, 10))}
                        className="settings-select-inline"
                      >
                        <option value="1">1</option>
                        <option value="5">5</option>
                        <option value="10">10</option>
                        <option value="15">15 (default)</option>
                        <option value="20">20</option>
                        <option value="25">25</option>
                        <option value="30">30</option>
                        <option value="40">40</option>
                      </select>
                    </div>

                    {data.currentUser && (data.currentUser.level >= 2 || data.currentUser.title === 'e2e_admin') && (
                      <label className="settings-checkbox-label">
                        <input
                          type="checkbox"
                          checked={(nodeletSettings[configuringNodelet.node_id]?.nw_nojunk || 0) === 1}
                          onChange={() => {
                            const current = nodeletSettings[configuringNodelet.node_id]?.nw_nojunk || 0
                            handleNodeletSettingChange(configuringNodelet.node_id, 'nw_nojunk', current === 1 ? 0 : 1)
                          }}
                        />
                        <strong>No junk</strong>
                        <div className="settings-hint-block">
                          Hide low-quality writeups (editors only)
                        </div>
                      </label>
                    )}
                  </div>
                </div>
              )}
            </div>
          )}
        </div>
      )}

      {/* Notifications tab */}
      {activeTab === 'notifications' && (
        <div>
          <h2>Notification Preferences</h2>

          <p className="settings-intro">
            Choose which types of notifications you want to receive. Enabled notifications will appear in your
            Notifications nodelet (if added to your sidebar) and in the mobile notifications drawer.
          </p>

          <fieldset className="settings-fieldset">
            <legend>Available Notifications</legend>

            {(data.notificationPreferences || []).length > 0 ? (
              <div className="settings-scroll-list">
                {(data.notificationPreferences || []).map((notif) => (
                  <label
                    key={notif.node_id}
                    className={`settings-notification-label${notificationPrefs[notif.node_id] ? ' active' : ''}`}
                  >
                    <input
                      type="checkbox"
                      checked={notificationPrefs[notif.node_id] || false}
                      onChange={(e) => setNotificationPrefs(prev => ({ ...prev, [notif.node_id]: e.target.checked }))}
                    />
                    <strong>{notif.title}</strong>
                  </label>
                ))}
              </div>
            ) : (
              <p className="settings-hint" style={{ fontStyle: 'italic' }}>
                No notification types are currently available. Notification types are configured by site administrators.
              </p>
            )}
          </fieldset>

          <div className="settings-how-to">
            <h3>How Notifications Work</h3>
            <ul>
              <li>Enabled notifications appear in your sidebar's Notifications nodelet</li>
              <li>On mobile, access notifications via the bell icon in the bottom navigation</li>
              <li>Dismiss individual notifications by clicking the × button</li>
              <li>Some notifications link to relevant content - click to view</li>
            </ul>
          </div>

          {/* Link to add Notifications nodelet if not present */}
          {!nodelets.some(n => n.title === 'Notifications') && (
            <div className="settings-tip-box">
              <strong>Tip:</strong> Add the Notifications nodelet to your sidebar to see notifications on desktop.
              <button
                type="button"
                onClick={() => {
                  const notifNodelet = (data.availableNodelets || []).find(n => n.title === 'Notifications')
                  if (notifNodelet) {
                    handleAddNodelet(notifNodelet)
                  }
                }}
                className="settings-btn-primary"
                style={{ marginLeft: '12px', padding: '6px 12px', fontSize: '13px' }}
              >
                Add Notifications Nodelet
              </button>
            </div>
          )}
        </div>
      )}

      {/* Advanced tab */}
      {activeTab === 'advanced' && (
        <div>
          <h2 className="settings-section-header">Theme</h2>

          <fieldset className="settings-fieldset">
            <legend>Site Theme / Stylesheet</legend>
            <p className="settings-description">
              Choose your site theme. Click "Preview" to see how it looks, then "Save Changes" to keep it.
              More themes are available at <a href="/title/The%20Catwalk" className="settings-link">The Catwalk</a> and <a href="/title/Theme%20Nirvana" className="settings-link">Theme Nirvana</a>.
            </p>

            <div className="settings-theme-row">
              <select
                id="settings-theme-selector"
                value={settingsPrefs.userstyle || data.defaultStylesheetId || ''}
                onChange={(e) => handlePrefChange('userstyle', e.target.value)}
                className="settings-select"
              >
                {(data.availableStylesheets || []).map(style => (
                  <option key={style.node_id} value={style.node_id}>
                    {style.title}
                  </option>
                ))}
              </select>

              <button
                type="button"
                onClick={() => {
                  const themeId = settingsPrefs.userstyle || data.defaultStylesheetId
                  if (themeId) {
                    let zenSheet = document.getElementById('zensheet')
                    // If zensheet doesn't exist (user on default theme), create it
                    if (!zenSheet) {
                      zenSheet = document.createElement('link')
                      zenSheet.id = 'zensheet'
                      zenSheet.rel = 'stylesheet'
                      zenSheet.type = 'text/css'
                      zenSheet.media = 'screen,tv,projection'
                      // Insert after basesheet
                      const baseSheet = document.getElementById('basesheet')
                      if (baseSheet && baseSheet.parentNode) {
                        baseSheet.parentNode.insertBefore(zenSheet, baseSheet.nextSibling)
                      } else {
                        document.head.appendChild(zenSheet)
                      }
                    }
                    zenSheet.href = `/css/${themeId}.css`
                  }
                }}
                className="settings-btn-primary"
              >
                Preview
              </button>

              {data.currentStylesheet && (
                <span className="settings-current-value">
                  Current: <strong>{data.currentStylesheet}</strong>
                </span>
              )}
            </div>
          </fieldset>

          <h2 className="settings-section-header">Page Display</h2>

          {/* Writeup Headers */}
          <fieldset className="settings-fieldset">
            <legend>Writeup Headers</legend>

            <label className="settings-checkbox-label">
              <input
                type="checkbox"
                checked={!(advancedPrefs.info_authorsince_off === 1)}
                onChange={() => handleToggleAdvancedPref('info_authorsince_off')}
              />
              <strong>Show how long ago the author was here</strong>
            </label>
          </fieldset>

          {/* Homenodes */}
          <fieldset className="settings-fieldset">
            <legend>Homenodes</legend>
            <p className="settings-description">
              Control what information is displayed on your homenode.
            </p>

            <label className="settings-checkbox-label">
              <input
                type="checkbox"
                checked={advancedPrefs.hidemsgme === 1}
                onChange={() => handleToggleAdvancedPref('hidemsgme')}
              />
              <strong>I am anti-social.</strong>
              <div className="settings-hint-block">
                So don't display the user /msg box in users' homenodes.
              </div>
            </label>

            <label className="settings-checkbox-label">
              <input
                type="checkbox"
                checked={advancedPrefs.hidemsgyou === 1}
                onChange={() => handleToggleAdvancedPref('hidemsgyou')}
              />
              <strong>No one talks to me either</strong>
              <div className="settings-hint-block">
                On homenodes, hide the '/msgs from me' link to Message Inbox
              </div>
            </label>

            <label className="settings-checkbox-label">
              <input
                type="checkbox"
                checked={advancedPrefs.hidevotedata === 1}
                onChange={() => handleToggleAdvancedPref('hidevotedata')}
              />
              <strong>I'm careless with my votes and C!s</strong>
              <div className="settings-hint-block">
                Don't show them on my homenode
              </div>
            </label>

            <label className="settings-checkbox-label">
              <input
                type="checkbox"
                checked={advancedPrefs.hidehomenodeUG === 1}
                onChange={() => handleToggleAdvancedPref('hidehomenodeUG')}
              />
              <strong>I'm a loner, Dottie, a rebel.</strong>
              <div className="settings-hint-block">
                Don't list my usergroups on my homenode.
              </div>
            </label>

            <label className="settings-checkbox-label">
              <input
                type="checkbox"
                checked={advancedPrefs.hidehomenodeUC === 1}
                onChange={() => handleToggleAdvancedPref('hidehomenodeUC')}
              />
              <strong>I'm a secret librarian.</strong>
              <div className="settings-hint-block">
                Don't list my categories on my homenode.
              </div>
            </label>

            <label className="settings-checkbox-label">
              <input
                type="checkbox"
                checked={advancedPrefs.showrecentwucount === 1}
                onChange={() => handleToggleAdvancedPref('showrecentwucount')}
              />
              <strong>Let the world know, I'm a fervent noder, and I love it!</strong>
              <div className="settings-hint-block">
                Show recent writeup count in homenode.
              </div>
            </label>

            <label className="settings-checkbox-label">
              <input
                type="checkbox"
                checked={!(advancedPrefs.hidelastnoded === 1)}
                onChange={() => handleToggleAdvancedPref('hidelastnoded')}
              />
              <strong>Link to user's most recently created writeup on their homenode</strong>
            </label>
          </fieldset>

          {/* Other Display Options */}
          <fieldset className="settings-fieldset">
            <legend>Other Display Options</legend>

            <label className="settings-checkbox-label">
              <input
                type="checkbox"
                checked={!(advancedPrefs.hideauthore2node === 1)}
                onChange={() => handleToggleAdvancedPref('hideauthore2node')}
              />
              <strong>Show who created a writeup page title (a.k.a. e2node)</strong>
            </label>

            <label className="settings-checkbox-label">
              <input
                type="checkbox"
                checked={advancedPrefs.noSoftLinks === 1}
                onChange={() => handleToggleAdvancedPref('noSoftLinks')}
              />
              <strong>Hide softlinks</strong>
            </label>

            <label className="settings-checkbox-label">
              <input
                type="checkbox"
                checked={!(advancedPrefs.nosocialbookmarking === 1)}
                onChange={() => handleToggleAdvancedPref('nosocialbookmarking')}
              />
              <strong>Allow others to see social bookmarking buttons on my writeups</strong>
              <div className="settings-hint-block">
                Note: When unchecked, also hides social bookmarking buttons on other people's writeups
              </div>
            </label>
          </fieldset>

          {/* Information Section */}
          <h2 className="settings-section-header">Information</h2>

          {/* Writeup Maintenance */}
          <fieldset className="settings-fieldset">
            <legend>Writeup Maintenance</legend>

            <label className="settings-checkbox-label">
              <input
                type="checkbox"
                checked={!(advancedPrefs.no_notify_kill === 1)}
                onChange={() => handleToggleAdvancedPref('no_notify_kill')}
              />
              <strong>Tell me when my writeups are deleted</strong>
            </label>

            <label className="settings-checkbox-label">
              <input
                type="checkbox"
                checked={!(advancedPrefs.no_editnotification === 1)}
                onChange={() => handleToggleAdvancedPref('no_editnotification')}
              />
              <strong>Tell me when my writeups get edited by an editor or administrator</strong>
            </label>
          </fieldset>

          {/* Writeup Response */}
          <fieldset className="settings-fieldset">
            <legend>Writeup Response</legend>

            <label className="settings-checkbox-label">
              <input
                type="checkbox"
                checked={!(advancedPrefs.no_coolnotification === 1)}
                onChange={() => handleToggleAdvancedPref('no_coolnotification')}
              />
              <strong>Tell me when my writeups get C!ed ('cooled')</strong>
            </label>

            <label className="settings-checkbox-label">
              <input
                type="checkbox"
                checked={!(advancedPrefs.no_likeitnotification === 1)}
                onChange={() => handleToggleAdvancedPref('no_likeitnotification')}
              />
              <strong>Tell me when Guest Users like my writeups</strong>
            </label>

            <label className="settings-checkbox-label">
              <input
                type="checkbox"
                checked={!(advancedPrefs.no_bookmarknotification === 1)}
                onChange={() => handleToggleAdvancedPref('no_bookmarknotification')}
              />
              <strong>Tell me when my writeups get bookmarked on E2</strong>
            </label>

            <label className="settings-checkbox-label">
              <input
                type="checkbox"
                checked={!(advancedPrefs.no_bookmarkinformer === 1)}
                onChange={() => handleToggleAdvancedPref('no_bookmarkinformer')}
              />
              <strong>Tell others when I bookmark a writeup on E2</strong>
            </label>

            {!(advancedPrefs.no_bookmarkinformer === 1) && (
              <label className="settings-checkbox-label settings-checkbox-nested">
                <input
                  type="checkbox"
                  checked={advancedPrefs.anonymous_bookmark === 1}
                  onChange={() => handleToggleAdvancedPref('anonymous_bookmark')}
                />
                <strong>but do it anonymously</strong>
              </label>
            )}
          </fieldset>

          {/* Social Bookmarking */}
          <fieldset className="settings-fieldset">
            <legend>Social Bookmarking</legend>

            <label className="settings-checkbox-label">
              <input
                type="checkbox"
                checked={!(advancedPrefs.no_socialbookmarknotification === 1)}
                onChange={() => handleToggleAdvancedPref('no_socialbookmarknotification')}
              />
              <strong>Tell me when my writeups get bookmarked on a social bookmarking site</strong>
            </label>

            <label className="settings-checkbox-label">
              <input
                type="checkbox"
                checked={!(advancedPrefs.no_socialbookmarkinformer === 1)}
                onChange={() => handleToggleAdvancedPref('no_socialbookmarkinformer')}
              />
              <strong>Tell others when I bookmark a writeup on a social bookmarking site</strong>
            </label>
          </fieldset>

          {/* Other Information */}
          <fieldset className="settings-fieldset">
            <legend>Other Information</legend>

            <label className="settings-checkbox-label">
              <input
                type="checkbox"
                checked={!(advancedPrefs.no_discussionreplynotify === 1)}
                onChange={() => handleToggleAdvancedPref('no_discussionreplynotify')}
              />
              <strong>Tell me when someone replies to my usergroup discussion posts</strong>
            </label>

            <label className="settings-checkbox-label">
              <input
                type="checkbox"
                checked={advancedPrefs.hidelastseen === 1}
                onChange={() => handleToggleAdvancedPref('hidelastseen')}
              />
              <strong>Don't tell anyone when I was last here</strong>
            </label>
          </fieldset>

          {/* Messages Section */}
          <h2 className="settings-section-header">Messages</h2>

          <fieldset className="settings-fieldset">
            <legend>Message Settings</legend>

            <label className="settings-checkbox-label">
              <input
                type="checkbox"
                checked={advancedPrefs.getofflinemsgs === 1}
                onChange={() => handleToggleAdvancedPref('getofflinemsgs')}
              />
              <strong>Get online-only messages, even while offline</strong>
            </label>

            <div className="settings-info-box">
              <p>
                <strong>Note:</strong> The Message Inbox now always displays messages sorted by most recent first (newest at top).
              </p>
            </div>
          </fieldset>

          {/* Miscellaneous Section */}
          <h2 className="settings-section-header">Miscellaneous</h2>

          <fieldset className="settings-fieldset">
            <legend>Chatterbox</legend>

            <div className="settings-info-box">
              <p>
                <strong>Note:</strong> The modern chatterbox automatically validates all commands. Messages starting with "/" are processed as commands and will show an error if the command is invalid.
              </p>
            </div>
          </fieldset>

          <fieldset className="settings-fieldset">
            <legend>Other Options</legend>

            <label className="settings-checkbox-label">
              <input
                type="checkbox"
                checked={advancedPrefs.hidenodeshells === 1}
                onChange={() => handleToggleAdvancedPref('hidenodeshells')}
              />
              <strong>Hide nodeshells in search results and softlink tables</strong>
              <div className="settings-hint-block">
                A nodeshell is a page on Everything2 with a title but no content
              </div>
            </label>

            <label className="settings-checkbox-label">
              <input
                type="checkbox"
                checked={advancedPrefs.GPoptout === 1}
                onChange={() => handleToggleAdvancedPref('GPoptout')}
              />
              <strong>Opt me out of the GP System</strong>
              <div className="settings-hint-block">
                GP is a points reward system
              </div>
            </label>

            <label className="settings-checkbox-label">
              <input
                type="checkbox"
                checked={advancedPrefs.defaultpostwriteup === 1}
                onChange={() => handleToggleAdvancedPref('defaultpostwriteup')}
              />
              <strong>Publish immediately by default</strong>
              <div className="settings-hint-block">
                Older users may appreciate having 'publish immediately' initially selected instead 'post as draft'
              </div>
            </label>

            <label className="settings-checkbox-label">
              <input
                type="checkbox"
                checked={advancedPrefs.HideNewWriteups === 1}
                onChange={() => handleToggleAdvancedPref('HideNewWriteups')}
              />
              <strong>Hide your new writeups by default</strong>
              <div className="settings-hint-block">
                Some writeups (daylogs, maintenance) always default to hidden
              </div>
            </label>

          </fieldset>
        </div>
      )}

      {/* Admin tab - editors only */}
      {activeTab === 'admin' && Boolean(data.isEditor) && (
        <div>
          <h2 className="settings-section-header">Editor Settings</h2>

          <fieldset className="settings-fieldset">
            <legend>Editor Options</legend>

            <label className="settings-checkbox-label">
              <input
                type="checkbox"
                checked={editorPrefs.hidenodenotes === 1}
                onChange={() => handleToggleEditorPref('hidenodenotes')}
              />
              <strong>Hide Node Notes</strong>
              <div className="settings-hint-block">
                Don't display node notes on writeup pages
              </div>
            </label>
          </fieldset>

          <h2 className="settings-section-header">Chatterbox Macros</h2>

          <p className="settings-description">
            Macros allow you to quickly send predefined messages in the chatterbox.
            Enable a macro by checking "Use", then customize the text.
          </p>

          <div style={{ overflowX: 'auto' }}>
            <table className="settings-macros-table">
              <thead>
                <tr>
                  <th>Use?</th>
                  <th>Name</th>
                  <th>Text</th>
                </tr>
              </thead>
              <tbody>
                {macros.map((macro) => (
                  <tr key={macro.name}>
                    <td>
                      <input
                        type="checkbox"
                        checked={Boolean(macro.enabled)}
                        onChange={() => handleToggleMacro(macro.name)}
                      />
                    </td>
                    <td>
                      <code>{macro.name}</code>
                    </td>
                    <td>
                      <textarea
                        value={macro.text}
                        onChange={(e) => handleMacroTextChange(macro.name, e.target.value)}
                        rows={6}
                        maxLength={MAX_MACRO_LENGTH}
                        className="settings-textarea-macro"
                      />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="settings-macros-help">
            <p>
              If you will use a macro, make sure the "Use" column is checked.
              If you won't use it, uncheck it, and it will be deleted.
              The text in the "macro" area of a "non-use" macro is the default text,
              although you can change it (but be sure to check the "use" checkbox if you want to keep it).
            </p>
            <p>
              Each macro must currently begin with <code>/say</code> (which indicates that you're saying something).
              Note: each macro is limited to {MAX_MACRO_LENGTH} characters.
            </p>
            <p>
              Note: instead of square brackets, [ and ],
              you'll have to use curly brackets, {'{'} and {'}'} instead.
            </p>
            <p>
              There is more information about macros at{' '}
              <a href="/title/macro%20FAQ" className="settings-link">macro FAQ</a>.
            </p>
          </div>
        </div>
      )}

      {/* Edit Profile tab */}
      {activeTab === 'profile' && (
        <div>
          {/* Password mismatch warning */}
          {hasPasswordInput && !passwordsMatch && (
            <div className="settings-warning-box">
              Passwords do not match - please correct before saving
            </div>
          )}

          {/* Account Settings Section */}
          <h2 className="settings-section-header">Account Settings</h2>

          <fieldset className="settings-fieldset">
            <legend>Credentials</legend>

            {/* Real name */}
            <div className="settings-form-row">
              <label className="settings-form-label">Real Name</label>
              <input
                type="text"
                name="realname"
                value={profileData.realname}
                onChange={handleProfileInputChange}
                className="settings-input-name"
              />
              {data.profileData?.realname && (
                <div className="settings-current-value">
                  Currently: {data.profileData.realname}
                </div>
              )}
            </div>

            {/* Password */}
            <div className="settings-form-row">
              <label className="settings-form-label">Change Password</label>
              <div className="settings-form-row-inline">
                <input
                  type="password"
                  name="passwd"
                  value={profileData.passwd}
                  onChange={handleProfileInputChange}
                  placeholder="Leave blank to keep current"
                  className={`settings-input-password${hasPasswordInput ? (passwordsMatch ? ' match' : ' mismatch') : ''}`}
                />
                {hasPasswordInput && (
                  <span className={`settings-password-match-icon${passwordsMatch ? ' match' : ' mismatch'}`}>
                    {passwordsMatch ? '✓' : '✗'}
                  </span>
                )}
              </div>
            </div>

            {/* Confirm Password */}
            <div className="settings-form-row">
              <label className="settings-form-label">Confirm Password</label>
              <div className="settings-form-row-inline">
                <input
                  type="password"
                  value={confirmPasswd}
                  onChange={(e) => setConfirmPasswd(e.target.value)}
                  placeholder="Re-enter new password"
                  className={`settings-input-password${hasPasswordInput ? (passwordsMatch ? ' match' : ' mismatch') : ''}`}
                />
                {hasPasswordInput && (
                  <span className={`settings-password-match-icon${passwordsMatch ? ' match' : ' mismatch'}`}>
                    {passwordsMatch ? '✓' : '✗'}
                  </span>
                )}
              </div>
              {hasPasswordInput && !passwordsMatch && (
                <div className="settings-password-error">
                  Passwords do not match
                </div>
              )}
            </div>

            {/* Email */}
            <div className="settings-form-row">
              <label className="settings-form-label">Email Address</label>
              <input
                type="email"
                name="email"
                value={profileData.email}
                onChange={handleProfileInputChange}
                className="settings-input-name"
              />
              {data.profileData?.email && (
                <div className="settings-current-value">
                  Currently: {data.profileData.email}
                </div>
              )}
            </div>
          </fieldset>

          {/* User image section */}
          {data.profileData?.imgsrc && (
            <fieldset className="settings-fieldset">
              <legend>Profile Image</legend>
              <img
                src={`/${data.profileData.imgsrc}`}
                alt={`${data.currentUser?.title}'s image`}
                className="settings-profile-image"
              />
              <label className="settings-checkbox-label">
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
          <h2 className="settings-section-header">Profile Information</h2>

          <fieldset className="settings-fieldset">
            <legend>About You</legend>

            {/* Mission drive */}
            <div className="settings-form-row">
              <label className="settings-form-label">Mission drive within everything</label>
              <input
                type="text"
                name="mission"
                value={profileData.mission}
                onChange={handleProfileInputChange}
                className="settings-input-wide"
              />
            </div>

            {/* Specialties */}
            <div className="settings-form-row">
              <label className="settings-form-label">Specialties</label>
              <input
                type="text"
                name="specialties"
                value={profileData.specialties}
                onChange={handleProfileInputChange}
                className="settings-input-wide"
              />
            </div>

            {/* School/Company */}
            <div className="settings-form-row">
              <label className="settings-form-label">School/Company</label>
              <input
                type="text"
                name="employment"
                value={profileData.employment}
                onChange={handleProfileInputChange}
                className="settings-input-wide"
              />
            </div>

            {/* Motto */}
            <div className="settings-form-row">
              <label className="settings-form-label">Motto</label>
              <input
                type="text"
                name="motto"
                value={profileData.motto}
                onChange={handleProfileInputChange}
                className="settings-input-wide"
              />
            </div>
          </fieldset>

          {/* Bookmarks section */}
          {data.bookmarks && data.bookmarks.length > 0 && (
            <>
              <h2 className="settings-section-header">Bookmarks</h2>

              <fieldset className="settings-fieldset">
                <legend>Manage Bookmarks</legend>
                <p className="settings-description">
                  Select bookmarks to remove from your list.
                </p>
                <button
                  type="button"
                  onClick={handleCheckAllBookmarks}
                  className="settings-btn-secondary settings-btn-sm"
                >
                  {selectedBookmarks.size === data.bookmarks.length ? 'Uncheck All' : 'Check All'}
                </button>
                <div className="settings-scroll-list-short">
                  {data.bookmarks.map((bookmark) => (
                    <label key={bookmark.node_id} className="settings-bookmark-item">
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
          <h2 className="settings-section-header">Bio</h2>

          <fieldset className="settings-fieldset">
            <legend>Your Bio</legend>
            <p className="settings-description">
              Write about yourself. This will appear on your homenode for other users to see.
            </p>

            {/* Rich/HTML mode toggle - using shared component */}
            <div className="settings-editor-toggle">
              <EditorModeToggle mode={editorMode} onToggle={toggleEditorMode} />
            </div>

            {/* Editor */}
            {editorMode === 'rich' ? (
              <div className="settings-editor-container">
                <MenuBar editor={bioEditor} />
                <EditorContent
                  editor={bioEditor}
                  className="settings-editor-content"
                />
              </div>
            ) : (
              <textarea
                value={htmlContent}
                onChange={handleHtmlChange}
                rows={15}
                className="settings-textarea"
              />
            )}

            {/* Live Preview */}
            <div style={{ marginTop: '16px' }}>
              <p className="settings-preview-label">
                <strong>Preview:</strong>
              </p>
              <PreviewContent
                editor={bioEditor}
                editorMode={editorMode}
                htmlContent={htmlContent}
                previewTrigger={previewTrigger}
              />
            </div>
          </fieldset>
        </div>
      )}
    </div>
  )
}

export default Settings
