import React, { useState, useCallback, useEffect, useRef } from 'react';
import { useEditor, EditorContent } from '@tiptap/react';
import { getE2EditorExtensions } from '../Editor/useE2Editor';
import { convertToE2Syntax } from '../Editor/E2LinkExtension';
import { convertRawBracketsToEntities, convertEntitiesToRawBrackets } from '../Editor/RawBracketExtension';
import { renderE2Content, breakTags } from '../Editor/E2HtmlSanitizer';
import MenuBar from '../Editor/MenuBar';
import PreviewContent from '../Editor/PreviewContent';
import PublishModal from './PublishModal';
import '../Editor/E2Editor.css';

// Inline styles for spinner animation (mode toggle styles now in E2Editor.css)
const editorStyles = `
  @keyframes e2-spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }
`;

// Spinner component for save status
const SaveSpinner = () => (
  <span className="editor-beta-spinner" />
);

// Delete Confirmation Modal Component
const DeleteConfirmModal = ({ draft, onConfirm, onCancel, deleting }) => {
  return (
    <div className="editor-beta-modal-overlay">
      <div className="editor-beta-modal">
        <h3 className="editor-beta-modal-title">Delete Draft?</h3>
        <p className="editor-beta-modal-body">
          Are you sure you want to delete "<strong>{draft.title}</strong>"? This action cannot be undone.
        </p>
        <div className="editor-beta-modal-actions">
          <button
            onClick={onCancel}
            disabled={deleting}
            className="editor-beta-modal-btn editor-beta-modal-btn--cancel"
          >
            Cancel
          </button>
          <button
            onClick={onConfirm}
            disabled={deleting}
            className="editor-beta-modal-btn editor-beta-modal-btn--danger"
          >
            {deleting ? 'Deleting...' : 'Delete'}
          </button>
        </div>
      </div>
    </div>
  );
};

// Version History Modal Component
const VersionHistoryModal = ({ nodeId, onClose, onRestore }) => {
  const [versions, setVersions] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedVersion, setSelectedVersion] = useState(null);
  const [previewContent, setPreviewContent] = useState('');
  const [restoring, setRestoring] = useState(false);

  useEffect(() => {
    const fetchHistory = async () => {
      try {
        const response = await fetch(`/api/autosave/${nodeId}/history`);
        const result = await response.json();
        if (result.success) {
          setVersions(result.versions || []);
        }
      } catch (err) {
        console.error('Failed to load version history:', err);
      }
      setLoading(false);
    };
    fetchHistory();
  }, [nodeId]);

  const loadVersionPreview = async (version) => {
    setSelectedVersion(version);
    // Fetch full content for preview
    try {
      const response = await fetch(`/api/autosave/${nodeId}`);
      const result = await response.json();
      if (result.success) {
        const fullVersion = result.autosaves.find(a => a.autosave_id === version.autosave_id);
        if (fullVersion) {
          // Use client-side rendering
          const { html: renderedHtml } = renderE2Content(fullVersion.doctext);
          setPreviewContent(renderedHtml);
        }
      }
    } catch (err) {
      console.error('Failed to load version preview:', err);
    }
  };

  const handleRestore = async () => {
    if (!selectedVersion) return;
    setRestoring(true);
    try {
      const response = await fetch(`/api/autosave/${selectedVersion.autosave_id}/restore`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' }
      });
      const result = await response.json();
      if (result.success) {
        onRestore();
        onClose();
      }
    } catch (err) {
      console.error('Restore failed:', err);
    }
    setRestoring(false);
  };

  const formatDate = (dateStr) => {
    const date = new Date(dateStr);
    return date.toLocaleString();
  };

  return (
    <div className="editor-beta-modal-overlay">
      <div className="editor-beta-modal editor-beta-modal--wide">
        {/* Header */}
        <div className="editor-beta-version-modal-header">
          <h2 className="editor-beta-version-modal-title">Version History</h2>
          <button
            onClick={onClose}
            className="editor-beta-modal-btn editor-beta-modal-btn--cancel"
          >
            Close
          </button>
        </div>

        {/* Content */}
        <div className="editor-beta-version-modal-content">
          {/* Version list */}
          <div className="editor-beta-version-list">
            {loading ? (
              <p className="editor-beta-version-empty">Loading...</p>
            ) : versions.length === 0 ? (
              <p className="editor-beta-version-empty">
                No previous versions yet. Version history is created when you save or autosave.
              </p>
            ) : (
              versions.map((version) => (
                <div
                  key={version.autosave_id}
                  onClick={() => loadVersionPreview(version)}
                  className={`editor-beta-version-item${selectedVersion?.autosave_id === version.autosave_id ? ' editor-beta-version-item--selected' : ''}`}
                >
                  <div className="editor-beta-version-date">
                    {formatDate(version.createtime)}
                  </div>
                  <div className="editor-beta-version-meta">
                    <span className={`editor-beta-version-badge ${version.save_type === 'manual' ? 'editor-beta-version-badge--manual' : 'editor-beta-version-badge--auto'}`}>
                      {version.save_type === 'manual' ? 'Saved' : 'Auto'}
                    </span>
                    <span className="editor-beta-version-size">
                      {Math.round((version.content_length || 0) / 1024 * 10) / 10} KB
                    </span>
                  </div>
                </div>
              ))
            )}
          </div>

          {/* Preview pane */}
          <div className="editor-beta-version-preview">
            {selectedVersion ? (
              <>
                <div className="editor-beta-version-preview-header">
                  <span className="editor-beta-version-preview-date">
                    Preview of version from {formatDate(selectedVersion.createtime)}
                  </span>
                  <button
                    onClick={handleRestore}
                    disabled={restoring}
                    className="editor-beta-modal-btn editor-beta-modal-btn--success"
                  >
                    {restoring ? 'Restoring...' : 'Restore This Version'}
                  </button>
                </div>
                <div
                  className="editor-beta-version-preview-content"
                  dangerouslySetInnerHTML={{ __html: previewContent }}
                />
              </>
            ) : (
              <p className="editor-beta-version-empty">
                Select a version to preview
              </p>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

/**
 * EditorBeta - Tiptap editor beta test page
 *
 * Features:
 * - Drafts sidebar for loading existing drafts
 * - Rich text editing with E2-approved HTML tags
 * - Save/create drafts with title editing
 * - Publication status management
 * - Client-side preview with E2 link parsing (uses DOMPurify)
 * - Autosave: saves to main draft every 60s, stashes previous version to history
 * - Version history popup to view/restore previous versions
 */
const EditorBeta = ({ data }) => {
  const { approvedTags, canAccess, username, drafts: initialDrafts, pagination: initialPagination, statuses = [], preferRawHtml, pageTitle = 'Drafts', viewingOther = false, targetUser = null } = data || {};

  // When viewing another user's drafts, the page is read-only
  // Coerce to boolean to avoid React rendering "0" from Perl
  const isReadOnly = Boolean(viewingOther);
  // Handle null/undefined drafts gracefully
  const safeDrafts = initialDrafts || [];
  const safePagination = initialPagination || { offset: 0, limit: 20, total: 0, has_more: false };

  // Detect mobile viewport
  const [isMobile, setIsMobile] = useState(() =>
    typeof window !== 'undefined' && window.innerWidth < 768
  );

  // State
  const [showPreview, setShowPreview] = useState(true);
  const [previewTrigger, setPreviewTrigger] = useState(0); // Trigger preview updates
  const [selectedDraft, setSelectedDraft] = useState(null);
  const [sidebarCollapsed, setSidebarCollapsed] = useState(() =>
    typeof window !== 'undefined' && window.innerWidth < 768
  );
  const [drafts, setDrafts] = useState(safeDrafts);
  const [draftTitle, setDraftTitle] = useState('');
  const [draftStatus, setDraftStatus] = useState('private');
  const [saving, setSaving] = useState(false);
  const [lastSaveTime, setLastSaveTime] = useState(null);
  const [lastSaveType, setLastSaveType] = useState(null); // 'manual' or 'auto'
  const [showVersionHistory, setShowVersionHistory] = useState(false);
  const [editMode, setEditMode] = useState(preferRawHtml ? 'html' : 'rich'); // 'rich' or 'html'
  const [rawHtmlContent, setRawHtmlContent] = useState('');
  const [pagination, setPagination] = useState(safePagination);
  const [loadingMore, setLoadingMore] = useState(false);
  const [showPublishModal, setShowPublishModal] = useState(false);
  const [deleteModalDraft, setDeleteModalDraft] = useState(null);
  const [deleting, setDeleting] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState(null);
  const [searching, setSearching] = useState(false);

  // Refs for autosave
  const autosaveTimerRef = useRef(null);
  const lastSavedContentRef = useRef('');

  const defaultContent = `
    <h2>Welcome to Your Drafts</h2>
    <p>Start writing here, or select an existing draft from the sidebar.</p>
    <p>Your work is automatically saved as you type.</p>
  `;

  // Track if this is the first focus on the editor with default content
  const hasEditedRef = useRef(false);

  const editor = useEditor({
    extensions: getE2EditorExtensions({
      starterKit: { heading: { levels: [1, 2, 3, 4, 5, 6] } },
      table: { resizable: false }
    }),
    content: isReadOnly ? '' : defaultContent,
    editable: !isReadOnly,
    onUpdate: () => {
      // Trigger live preview update
      setPreviewTrigger(prev => prev + 1);
    },
    editorProps: {
      attributes: {
        class: 'e2-editor-content',
        spellcheck: isReadOnly ? 'false' : 'true',
        'aria-label': 'Draft content',
        'role': 'textbox',
        'aria-multiline': 'true',
      },
      handleDOMEvents: {
        focus: (view) => {
          // Clear default content on first focus if no draft is selected (not in read-only mode)
          if (!isReadOnly && !hasEditedRef.current && !selectedDraft) {
            const currentHtml = view.state.doc.textContent;
            // Check if content matches the default welcome text
            if (currentHtml.includes('Welcome to Your Drafts')) {
              view.dispatch(
                view.state.tr.delete(0, view.state.doc.content.size)
              );
              hasEditedRef.current = true;
            }
          }
          return false; // Don't prevent default
        }
      }
    }
  });

  // Get current content from either rich editor or raw HTML textarea
  const getCurrentContent = useCallback(() => {
    if (editMode === 'html') {
      return rawHtmlContent;
    }
    if (editor) {
      const html = editor.getHTML();
      const withEntities = convertRawBracketsToEntities(html);
      return convertToE2Syntax(withEntities);
    }
    return '';
  }, [editor, editMode, rawHtmlContent]);

  // Toggle between rich and HTML editing modes and save preference
  const toggleEditMode = useCallback(() => {
    const newMode = editMode === 'rich' ? 'html' : 'rich';

    if (editMode === 'rich') {
      // Switching to HTML mode - capture current rich content
      if (editor) {
        const html = editor.getHTML();
        const withEntities = convertRawBracketsToEntities(html);
        setRawHtmlContent(convertToE2Syntax(withEntities));
      }
    } else {
      // Switching to rich mode - load HTML content into editor
      // First apply breakTags to convert plain-text newlines to proper HTML paragraphs
      // Then convert &#91; and &#93; entities back to parseable spans for TipTap
      if (editor) {
        const withBreaks = breakTags(rawHtmlContent);
        editor.commands.setContent(convertEntitiesToRawBrackets(withBreaks));
      }
    }

    setEditMode(newMode);

    // Save preference to server (fire-and-forget)
    fetch('/api/preferences/set', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ tiptap_editor_raw: newMode === 'html' ? 1 : 0 })
    }).catch(err => console.error('Failed to save editor mode preference:', err));
  }, [editor, editMode, rawHtmlContent]);

  // Autosave effect - saves directly to main draft, stashing previous version
  // Works with both rich and HTML editing modes
  useEffect(() => {
    if (!selectedDraft) return;
    // In rich mode, need editor; in HTML mode, we use rawHtmlContent
    if (editMode === 'rich' && !editor) return;

    // Clear any existing timer
    if (autosaveTimerRef.current) {
      clearInterval(autosaveTimerRef.current);
    }

    // Set up autosave every 60 seconds
    autosaveTimerRef.current = setInterval(async () => {
      // Use getCurrentContent to ensure raw brackets are converted to entities
      const currentContent = getCurrentContent();

      // Only autosave if content has changed from last saved version
      if (currentContent !== lastSavedContentRef.current && selectedDraft) {
        setSaving(true);

        try {
          const response = await fetch('/api/autosave', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              node_id: selectedDraft.node_id,
              doctext: currentContent
            })
          });

          const result = await response.json();
          if (result.success && result.saved) {
            lastSavedContentRef.current = currentContent;
            setLastSaveTime(new Date().toLocaleTimeString());
            setLastSaveType('auto');

            // Update draft in sidebar list
            setDrafts(prev => prev.map(d =>
              d.node_id === selectedDraft.node_id
                ? { ...d, doctext: currentContent }
                : d
            ));

            // Trigger preview update
            setPreviewTrigger(prev => prev + 1);
          }
        } catch (err) {
          console.error('Autosave failed:', err);
        }
        setSaving(false);
      }
    }, 60000);

    return () => {
      if (autosaveTimerRef.current) {
        clearInterval(autosaveTimerRef.current);
      }
    };
  }, [editor, selectedDraft, getCurrentContent, editMode]);

  // Load a draft into the editor
  const loadDraft = useCallback((draft) => {
    if (draft) {
      // For empty drafts, set to empty paragraph so editor is usable
      // (empty string '' can cause Tiptap issues)
      const content = draft.doctext || '<p></p>';

      // Load into both rich editor and raw HTML state
      // Apply breakTags to convert plain-text newlines to proper HTML paragraphs
      // Then convert &#91; and &#93; entities back to parseable spans for TipTap
      if (editor) {
        const withBreaks = breakTags(content);
        editor.commands.setContent(convertEntitiesToRawBrackets(withBreaks));
      }
      setRawHtmlContent(content);

      setSelectedDraft(draft);
      setDraftTitle(draft.title);
      setDraftStatus(draft.status || 'private');
      setLastSaveTime(null);
      setLastSaveType(null);
      lastSavedContentRef.current = draft.doctext || '';
    }
  }, [editor]);

  // Clear editor and start new
  const clearEditor = useCallback(() => {
    if (editor) {
      editor.commands.setContent(defaultContent);
    }
    setRawHtmlContent(defaultContent);
    setSelectedDraft(null);
    setDraftTitle('');
    setDraftStatus('private');
    setLastSaveTime(null);
    setLastSaveType(null);
    lastSavedContentRef.current = '';
    hasEditedRef.current = false; // Reset so welcome text clears on focus again
  }, [editor, defaultContent]);

  // Save draft (create or update) - manual save
  const saveDraft = useCallback(async () => {
    // In rich mode, need editor; in HTML mode, we use rawHtmlContent
    if (editMode === 'rich' && !editor) return;

    setSaving(true);

    const content = getCurrentContent();
    const title = draftTitle.trim() || 'Untitled Draft';

    try {
      let response;

      if (selectedDraft) {
        // Update existing draft
        response = await fetch(`/api/drafts/${selectedDraft.node_id}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            title,
            doctext: content,
            status: draftStatus
          })
        });
      } else {
        // Create new draft
        response = await fetch('/api/drafts', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            title,
            doctext: content
          })
        });
      }

      const result = await response.json();

      if (result.success) {
        lastSavedContentRef.current = content;
        setLastSaveTime(new Date().toLocaleTimeString());
        setLastSaveType('manual');

        // Update drafts list
        if (!selectedDraft && result.draft) {
          // New draft created
          const newDraft = {
            node_id: result.draft.node_id,
            title: result.draft.title || title,
            status: result.draft.status || 'private',
            doctext: content,
            createtime: new Date().toISOString()
          };
          setDrafts([newDraft, ...drafts]);
          setSelectedDraft(newDraft);
          setDraftTitle(newDraft.title);
        } else if (selectedDraft) {
          // Update existing draft in list
          setDrafts(drafts.map(d =>
            d.node_id === selectedDraft.node_id
              ? { ...d, title: result.updated?.title || title, status: result.updated?.status || draftStatus, doctext: content }
              : d
          ));
          if (result.updated?.title) {
            setDraftTitle(result.updated.title);
          }
        }

        // Trigger preview update
        setPreviewTrigger(prev => prev + 1);
      }
    } catch (err) {
      console.error('Save failed:', err);
    }

    setSaving(false);
  }, [editor, selectedDraft, draftTitle, draftStatus, drafts, editMode, getCurrentContent]);

  // Handle restore from version history
  const handleVersionRestore = useCallback(async () => {
    if (!selectedDraft) return;

    // Reload the draft content from server
    try {
      const response = await fetch(`/api/drafts/${selectedDraft.node_id}`);
      const result = await response.json();
      if (result.success && result.draft) {
        const content = result.draft.doctext || '';

        // Update both editor and raw HTML state
        if (editor) {
          editor.commands.setContent(content);
        }
        setRawHtmlContent(content);

        lastSavedContentRef.current = content;
        setLastSaveTime(new Date().toLocaleTimeString());
        setLastSaveType('manual');

        // Update in drafts list
        setDrafts(prev => prev.map(d =>
          d.node_id === selectedDraft.node_id
            ? { ...d, doctext: content }
            : d
        ));
      }
    } catch (err) {
      console.error('Failed to reload draft after restore:', err);
    }
  }, [editor, selectedDraft]);

  // Load more drafts (pagination)
  const loadMoreDrafts = useCallback(async () => {
    setLoadingMore(true);
    try {
      const nextOffset = pagination.offset + pagination.limit;
      const response = await fetch(`/api/drafts?limit=${pagination.limit}&offset=${nextOffset}`);
      const result = await response.json();

      if (result.success && result.drafts) {
        // Append new drafts to existing list
        setDrafts(prev => [...prev, ...result.drafts]);

        // Update pagination metadata
        if (result.pagination) {
          setPagination(result.pagination);
        }
      }
    } catch (err) {
      console.error('Failed to load more drafts:', err);
    }
    setLoadingMore(false);
  }, [pagination]);

  // Delete a draft
  const deleteDraft = useCallback(async (draft) => {
    setDeleting(true);
    try {
      const response = await fetch(`/api/drafts/${draft.node_id}`, {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' }
      });
      const result = await response.json();

      if (result.success) {
        // Remove from drafts list
        setDrafts(prev => prev.filter(d => d.node_id !== draft.node_id));

        // If this was the selected draft, clear the editor
        if (selectedDraft?.node_id === draft.node_id) {
          clearEditor();
        }

        // Also remove from search results if present
        if (searchResults) {
          setSearchResults(prev => prev.filter(d => d.node_id !== draft.node_id));
        }
      } else {
        console.error('Delete failed:', result.error);
        alert('Failed to delete draft: ' + (result.error || 'Unknown error'));
      }
    } catch (err) {
      console.error('Delete failed:', err);
      alert('Failed to delete draft. Please try again.');
    }
    setDeleting(false);
    setDeleteModalDraft(null);
  }, [selectedDraft, clearEditor, searchResults]);

  // Search drafts with debounce
  const searchTimerRef = useRef(null);

  const handleSearchChange = useCallback((e) => {
    const query = e.target.value;
    setSearchQuery(query);

    // Clear existing timer
    if (searchTimerRef.current) {
      clearTimeout(searchTimerRef.current);
    }

    // If empty, clear search results
    if (!query.trim()) {
      setSearchResults(null);
      setSearching(false);
      return;
    }

    // Debounce search
    setSearching(true);
    searchTimerRef.current = setTimeout(async () => {
      try {
        // Build search URL with optional other_user parameter
        let searchUrl = `/api/drafts/search?q=${encodeURIComponent(query.trim())}`;
        if (targetUser?.title) {
          searchUrl += `&other_user=${encodeURIComponent(targetUser.title)}`;
        }
        const response = await fetch(searchUrl);
        const result = await response.json();

        if (result.success) {
          setSearchResults(result.drafts);
        } else {
          console.error('Search failed:', result.error);
          setSearchResults([]);
        }
      } catch (err) {
        console.error('Search failed:', err);
        setSearchResults([]);
      }
      setSearching(false);
    }, 300);
  }, [targetUser]);

  // Cleanup search timer on unmount
  useEffect(() => {
    return () => {
      if (searchTimerRef.current) {
        clearTimeout(searchTimerRef.current);
      }
    };
  }, []);

  // Track viewport size for mobile detection
  useEffect(() => {
    const handleResize = () => {
      const mobile = window.innerWidth < 768;
      setIsMobile(mobile);
    };
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  if (!canAccess) {
    return (
      <div className="editor-beta-access-denied">
        <h1>{pageTitle}</h1>
        <p className="editor-beta-access-denied-msg">Please log in to use the drafts editor.</p>
      </div>
    );
  }

  const getStatusColor = (status) => {
    const colors = {
      'review': '#4060b0',
      'private': '#888',
      'shared': '#9c6',
      'findable': '#3bb5c3',
      'nuked': '#c75050',
      'removed': '#c75050'
    };
    return colors[status?.toLowerCase()] || '#507898';
  };

  const statusDescriptions = {
    'private': 'Only you can see this draft',
    'shared': 'Visible to collaborators',
    'findable': 'Visible to all logged-in users',
    'review': 'Submit for editor review'
  };

  return (
    <div className={`editor-beta-container${isMobile ? ' editor-beta-container--mobile' : ''}`}>
      {/* Version History Modal */}
      {showVersionHistory && selectedDraft && (
        <VersionHistoryModal
          nodeId={selectedDraft.node_id}
          onClose={() => setShowVersionHistory(false)}
          onRestore={handleVersionRestore}
        />
      )}

      {/* Delete Confirmation Modal */}
      {deleteModalDraft && (
        <DeleteConfirmModal
          draft={deleteModalDraft}
          onConfirm={() => deleteDraft(deleteModalDraft)}
          onCancel={() => setDeleteModalDraft(null)}
          deleting={deleting}
        />
      )}

      {/* Publish Modal */}
      {showPublishModal && selectedDraft && (
        <PublishModal
          draft={selectedDraft}
          onSuccess={(data) => {
            // Handle successful publication
            console.log('Published successfully:', data);
          }}
          onClose={() => setShowPublishModal(false)}
        />
      )}

      {/* Drafts Sidebar */}
      <div className={`editor-beta-sidebar${sidebarCollapsed ? ' editor-beta-sidebar--collapsed' : ''}${isMobile ? ' editor-beta-sidebar--mobile' : ''}${isMobile && !sidebarCollapsed ? ' editor-beta-sidebar--mobile-open' : ''}`}>
        <div className={`editor-beta-sidebar-header${sidebarCollapsed ? ' editor-beta-sidebar-header--collapsed' : ''}`}>
          {!sidebarCollapsed && <h3 className={`editor-beta-sidebar-title${isMobile ? ' editor-beta-sidebar-title--mobile' : ''}`}>Your Drafts</h3>}
          <button
            onClick={() => setSidebarCollapsed(!sidebarCollapsed)}
            className={`editor-beta-sidebar-toggle${isMobile ? ' editor-beta-sidebar-toggle--mobile' : ''}${isMobile && sidebarCollapsed ? ' editor-beta-sidebar-toggle--mobile-collapsed' : ''}`}
            title={sidebarCollapsed ? 'Show drafts' : 'Hide drafts'}
          >
            {sidebarCollapsed
              ? (isMobile ? 'Show Drafts ▼' : '>')
              : (isMobile ? 'Hide Drafts ▲' : '<')}
          </button>
        </div>

        {!sidebarCollapsed && (
          <>
            {/* Search bar */}
            <div className="editor-beta-search-wrapper">
              <input
                type="text"
                value={searchQuery}
                onChange={handleSearchChange}
                placeholder="Search drafts..."
                className={`editor-beta-search-input${searching ? ' editor-beta-search-input--loading' : ''}`}
              />
              {searching && (
                <span className="editor-beta-search-indicator">...</span>
              )}
            </div>

            {/* Show search results or regular drafts list */}
            {searchResults !== null ? (
              // Search results mode
              <>
                <div className="editor-beta-search-info">
                  {searchResults.length === 0
                    ? 'No drafts found'
                    : `Found ${searchResults.length} draft${searchResults.length === 1 ? '' : 's'}`}
                </div>
                <div className={`editor-beta-drafts-list${isMobile ? ' editor-beta-drafts-list--mobile' : ''}`}>
                  {searchResults.map((draft) => (
                    <div
                      key={draft.node_id}
                      className={`editor-beta-draft-card${selectedDraft?.node_id === draft.node_id ? ' editor-beta-draft-card--selected' : ''}`}
                    >
                      <div
                        onClick={() => loadDraft(draft)}
                        className="editor-beta-draft-card-body"
                      >
                        <div className="editor-beta-draft-title">
                          {draft.title}
                        </div>
                        <div className="editor-beta-draft-meta">
                          <span style={{ color: getStatusColor(draft.status) }}>{draft.status}</span>
                          <span>{draft.createtime?.split(' ')[0]}</span>
                        </div>
                      </div>
                      {!isReadOnly && (
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            setDeleteModalDraft(draft);
                          }}
                          title="Delete draft"
                          className="editor-beta-delete-btn"
                        >
                          Delete
                        </button>
                      )}
                    </div>
                  ))}
                </div>
                <button
                  onClick={() => {
                    setSearchQuery('');
                    setSearchResults(null);
                  }}
                  className="editor-beta-load-more-btn"
                >
                  Clear Search
                </button>
              </>
            ) : drafts.length === 0 ? (
              <p className="editor-beta-no-drafts">No drafts yet. Your drafts will appear here.</p>
            ) : (
              <>
                <div className={`editor-beta-drafts-list${isMobile ? ' editor-beta-drafts-list--mobile' : ''}`}>
                  {drafts.map((draft) => (
                    <div
                      key={draft.node_id}
                      className={`editor-beta-draft-card${selectedDraft?.node_id === draft.node_id ? ' editor-beta-draft-card--selected' : ''}`}
                    >
                      <div
                        onClick={() => loadDraft(draft)}
                        className="editor-beta-draft-card-body"
                      >
                        <div className="editor-beta-draft-title">
                          {draft.title}
                        </div>
                        <div className="editor-beta-draft-meta">
                          <span style={{ color: getStatusColor(draft.status) }}>{draft.status}</span>
                          <span>{draft.createtime?.split(' ')[0]}</span>
                        </div>
                      </div>
                      {!isReadOnly && (
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            setDeleteModalDraft(draft);
                          }}
                          title="Delete draft"
                          className="editor-beta-delete-btn"
                        >
                          Delete
                        </button>
                      )}
                    </div>
                  ))}
                </div>

                {/* Load More button */}
                {Boolean(pagination.has_more) && (
                  <button
                    onClick={loadMoreDrafts}
                    disabled={loadingMore}
                    className="editor-beta-load-more-btn"
                  >
                    {loadingMore ? 'Loading...' : 'Load More Drafts'}
                  </button>
                )}
              </>
            )}

            {!isReadOnly && (
              <button
                onClick={clearEditor}
                className="editor-beta-new-draft-btn"
              >
                + New Draft
              </button>
            )}
          </>
        )}
      </div>

      {/* Main Editor Area */}
      <div className="editor-beta-main">
        {/* Inject styles for animations and toggle */}
        <style>{editorStyles}</style>

        {/* Header with mode toggle in upper right */}
        <div className={`editor-beta-header${isMobile ? ' editor-beta-header--mobile' : ''}`}>
          {/* Read-only notice when viewing another user's drafts */}
          {isReadOnly && (
            <p className="editor-beta-readonly-notice">
              Viewing <a href={`/user/${encodeURIComponent(targetUser?.title)}`}>{targetUser?.title}</a>'s findable drafts (read-only)
            </p>
          )}

          {/* Spacer when not read-only to push toggle to right */}
          {!isReadOnly && <div className="editor-beta-header-spacer" />}

          {/* Stylized slider toggle - Rich/HTML */}
          <div
            className="e2-mode-toggle"
            onClick={toggleEditMode}
            title={editMode === 'rich' ? 'Switch to raw HTML editing' : 'Switch to rich text editing'}
          >
            <div
              className={`e2-mode-toggle-slider${editMode === 'rich' ? ' e2-mode-toggle-slider--left' : ' e2-mode-toggle-slider--right'}`}
            />
            <span className={`e2-mode-toggle-option ${editMode === 'rich' ? 'active' : ''}`}>
              Rich
            </span>
            <span className={`e2-mode-toggle-option ${editMode === 'html' ? 'active' : ''}`}>
              HTML
            </span>
          </div>
        </div>

        {/* Draft Title */}
        <div className={`editor-beta-title-wrapper${isMobile ? ' editor-beta-title-wrapper--mobile' : ''}`}>
          <input
            type="text"
            value={draftTitle}
            onChange={(e) => !isReadOnly && setDraftTitle(e.target.value)}
            readOnly={isReadOnly}
            placeholder={isReadOnly ? '' : 'Enter draft title...'}
            className={`editor-beta-title-input${isMobile ? ' editor-beta-title-input--mobile' : ''}${isReadOnly ? ' editor-beta-title-input--readonly' : ''}`}
          />
        </div>

        {/* Toolbar row */}
        <div className="editor-beta-toolbar-row">
          {/* Menu bar - only show in rich mode */}
          {editMode === 'rich' && editor && (
            <div className="editor-beta-toolbar-wrapper">
              <MenuBar editor={editor} />
            </div>
          )}

          {/* HTML mode indicator */}
          {editMode === 'html' && (
            <span className="editor-beta-html-hint">
              Editing raw HTML — E2 link syntax: [node name] or [node name|display text]
            </span>
          )}
        </div>

        {/* Editor - Rich text or HTML textarea based on mode */}
        {editMode === 'rich' ? (
          <div className="editor-beta-editor-container">
            <div
              className={`e2-editor-wrapper editor-beta-editor-wrapper${isMobile ? ' editor-beta-editor-wrapper--mobile' : ''}`}
            >
              <EditorContent editor={editor} />
            </div>
          </div>
        ) : (
          <textarea
            value={rawHtmlContent}
            onChange={(e) => {
              if (!isReadOnly) {
                setRawHtmlContent(e.target.value);
                setPreviewTrigger(prev => prev + 1);
              }
            }}
            readOnly={isReadOnly}
            aria-label="Draft content (HTML)"
            className={`editor-beta-html-textarea${isMobile ? ' editor-beta-html-textarea--mobile' : ''}${isReadOnly ? ' editor-beta-html-textarea--readonly' : ''}`}
            spellCheck={false}
            placeholder={isReadOnly ? '' : 'Enter HTML content here...'}
          />
        )}

        {/* Bottom bar: Controls (left) | Status dropdown + actions (right) */}
        <div className={`editor-beta-bottom-bar${isMobile ? ' editor-beta-bottom-bar--mobile' : ''}`}>
          {/* Left side: Version History button + Save status */}
          <div className="editor-beta-bottom-left">
            {/* Version History button - styled consistently (hidden in read-only mode) */}
            {selectedDraft && !isReadOnly && (
              <button
                onClick={() => setShowVersionHistory(true)}
                className="editor-beta-version-btn"
              >
                Version History
              </button>
            )}

            {/* Save status indicator - to the right of Version History (hidden in read-only mode) */}
            {!isReadOnly && (
              <div className="editor-beta-save-status">
                {saving ? (
                  <>
                    <SaveSpinner />
                    <span className="editor-beta-save-status--saving">Saving...</span>
                  </>
                ) : lastSaveTime ? (
                  <span className="editor-beta-save-status--saved">
                    {lastSaveType === 'auto' ? 'Autosaved' : 'Saved'} at {lastSaveTime}
                  </span>
                ) : null}
              </div>
            )}
          </div>

          {/* Controls - bottom right */}
          <div className={`editor-beta-controls${isMobile ? ' editor-beta-controls--mobile' : ''}`}>
            {/* Status dropdown - only when not read-only */}
            {!isReadOnly && (
              <select
                value={draftStatus}
                onChange={(e) => setDraftStatus(e.target.value)}
                className="editor-beta-status-select"
                title={statusDescriptions[draftStatus]}
              >
                {statuses.map((s) => (
                  <option key={s.id} value={s.name}>{s.name}</option>
                ))}
              </select>
            )}

            {/* Preview button */}
            <button
              onClick={() => setShowPreview(!showPreview)}
              className={`editor-beta-preview-btn${showPreview ? ' editor-beta-preview-btn--active' : ' editor-beta-preview-btn--inactive'}`}
            >
              {showPreview ? 'Hide Preview' : 'Preview'}
            </button>

            {/* Save button - only when not read-only */}
            {!isReadOnly && (
              <button
                onClick={saveDraft}
                disabled={saving}
                className="editor-beta-save-btn"
              >
                {saving ? 'Saving...' : (selectedDraft ? 'Save' : 'Create Draft')}
              </button>
            )}

          </div>
        </div>

        {/* Publish section - only visible when editing a saved draft (and not in read-only mode) */}
        {selectedDraft && !isReadOnly && (
          <div className="editor-beta-publish-section">
            <button
              onClick={() => setShowPublishModal(true)}
              disabled={saving}
              className="editor-beta-publish-btn"
            >
              Publish...
            </button>
            <span className="editor-beta-publish-hint">
              Ready to publish this draft as a writeup
            </span>
          </div>
        )}

        {/* Live preview pane */}
        {showPreview && (
          <div className="editor-beta-preview-section">
            <h3 className="editor-beta-preview-heading">Preview</h3>
            <PreviewContent
              editor={editor}
              editorMode={editMode}
              htmlContent={rawHtmlContent}
              previewTrigger={previewTrigger}
            />
          </div>
        )}
      </div>
    </div>
  );
};

export default EditorBeta;
