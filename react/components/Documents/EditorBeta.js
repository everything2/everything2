import React, { useState, useCallback, useEffect, useRef } from 'react';
import { useEditor, EditorContent } from '@tiptap/react';
import { getE2EditorExtensions } from '../Editor/useE2Editor';
import { convertToE2Syntax } from '../Editor/E2LinkExtension';
import { convertRawBracketsToEntities, convertEntitiesToRawBrackets } from '../Editor/RawBracketExtension';
import { renderE2Content } from '../Editor/E2HtmlSanitizer';
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
  <span style={{
    display: 'inline-block',
    width: '12px',
    height: '12px',
    border: '2px solid #ccc',
    borderTopColor: '#4060b0',
    borderRadius: '50%',
    animation: 'e2-spin 0.8s linear infinite',
    marginRight: '6px',
    verticalAlign: 'middle'
  }} />
);

// Delete Confirmation Modal Component
const DeleteConfirmModal = ({ draft, onConfirm, onCancel, deleting }) => {
  return (
    <div style={{
      position: 'fixed',
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      backgroundColor: 'rgba(0,0,0,0.5)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      zIndex: 1000
    }}>
      <div style={{
        backgroundColor: '#fff',
        borderRadius: '8px',
        width: '90%',
        maxWidth: '400px',
        padding: '20px',
        boxShadow: '0 4px 20px rgba(0,0,0,0.3)'
      }}>
        <h3 style={{ margin: '0 0 15px 0', color: '#38495e' }}>Delete Draft?</h3>
        <p style={{ color: '#555', marginBottom: '20px' }}>
          Are you sure you want to delete "<strong>{draft.title}</strong>"? This action cannot be undone.
        </p>
        <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end' }}>
          <button
            onClick={onCancel}
            disabled={deleting}
            style={{
              padding: '8px 16px',
              backgroundColor: '#f8f9f9',
              border: '1px solid #ccc',
              borderRadius: '4px',
              cursor: deleting ? 'not-allowed' : 'pointer',
              fontSize: '14px'
            }}
          >
            Cancel
          </button>
          <button
            onClick={onConfirm}
            disabled={deleting}
            style={{
              padding: '8px 16px',
              backgroundColor: deleting ? '#999' : '#c75050',
              color: '#fff',
              border: 'none',
              borderRadius: '4px',
              cursor: deleting ? 'wait' : 'pointer',
              fontSize: '14px'
            }}
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
    <div style={{
      position: 'fixed',
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      backgroundColor: 'rgba(0,0,0,0.5)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      zIndex: 1000
    }}>
      <div style={{
        backgroundColor: '#fff',
        borderRadius: '8px',
        width: '90%',
        maxWidth: '1000px',
        maxHeight: '80vh',
        display: 'flex',
        flexDirection: 'column',
        boxShadow: '0 4px 20px rgba(0,0,0,0.3)'
      }}>
        {/* Header */}
        <div style={{
          padding: '15px 20px',
          borderBottom: '1px solid #ddd',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center'
        }}>
          <h2 style={{ margin: 0, color: '#38495e', fontSize: '18px' }}>Version History</h2>
          <button
            onClick={onClose}
            style={{
              padding: '4px 10px',
              backgroundColor: '#f8f9f9',
              border: '1px solid #ccc',
              borderRadius: '4px',
              cursor: 'pointer',
              fontSize: '14px'
            }}
          >
            Close
          </button>
        </div>

        {/* Content */}
        <div style={{ display: 'flex', flex: 1, overflow: 'hidden' }}>
          {/* Version list */}
          <div style={{
            width: '300px',
            borderRight: '1px solid #ddd',
            overflowY: 'auto',
            padding: '10px'
          }}>
            {loading ? (
              <p style={{ color: '#666', padding: '10px' }}>Loading...</p>
            ) : versions.length === 0 ? (
              <p style={{ color: '#888', padding: '10px', fontSize: '13px' }}>
                No previous versions yet. Version history is created when you save or autosave.
              </p>
            ) : (
              versions.map((version) => (
                <div
                  key={version.autosave_id}
                  onClick={() => loadVersionPreview(version)}
                  style={{
                    padding: '10px',
                    marginBottom: '6px',
                    backgroundColor: selectedVersion?.autosave_id === version.autosave_id ? '#e8f4f8' : '#f8f9f9',
                    border: selectedVersion?.autosave_id === version.autosave_id ? '1px solid #3bb5c3' : '1px solid #eee',
                    borderRadius: '4px',
                    cursor: 'pointer'
                  }}
                >
                  <div style={{ fontSize: '13px', color: '#111', marginBottom: '4px' }}>
                    {formatDate(version.createtime)}
                  </div>
                  <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                    <span style={{
                      fontSize: '10px',
                      padding: '2px 6px',
                      borderRadius: '3px',
                      backgroundColor: version.save_type === 'manual' ? '#4060b0' : '#888',
                      color: '#fff'
                    }}>
                      {version.save_type === 'manual' ? 'Saved' : 'Auto'}
                    </span>
                    <span style={{ fontSize: '11px', color: '#666' }}>
                      {Math.round((version.content_length || 0) / 1024 * 10) / 10} KB
                    </span>
                  </div>
                </div>
              ))
            )}
          </div>

          {/* Preview pane */}
          <div style={{ flex: 1, padding: '15px', overflowY: 'auto' }}>
            {selectedVersion ? (
              <>
                <div style={{ marginBottom: '15px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span style={{ fontSize: '13px', color: '#666' }}>
                    Preview of version from {formatDate(selectedVersion.createtime)}
                  </span>
                  <button
                    onClick={handleRestore}
                    disabled={restoring}
                    style={{
                      padding: '6px 16px',
                      backgroundColor: restoring ? '#999' : '#4caf50',
                      color: '#fff',
                      border: 'none',
                      borderRadius: '4px',
                      cursor: restoring ? 'wait' : 'pointer',
                      fontSize: '13px'
                    }}
                  >
                    {restoring ? 'Restoring...' : 'Restore This Version'}
                  </button>
                </div>
                <div
                  style={{
                    padding: '15px',
                    border: '1px solid #ddd',
                    borderRadius: '4px',
                    backgroundColor: '#fafafa',
                    minHeight: '200px'
                  }}
                  dangerouslySetInnerHTML={{ __html: previewContent }}
                />
              </>
            ) : (
              <p style={{ color: '#888', textAlign: 'center', marginTop: '50px' }}>
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
  const isReadOnly = viewingOther;
  // Handle null/undefined drafts gracefully
  const safeDrafts = initialDrafts || [];
  const safePagination = initialPagination || { offset: 0, limit: 20, total: 0, has_more: false };

  // State
  const [showPreview, setShowPreview] = useState(true);
  const [previewTrigger, setPreviewTrigger] = useState(0); // Trigger preview updates
  const [selectedDraft, setSelectedDraft] = useState(null);
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);
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
      // Preprocess to convert &#91; and &#93; entities back to parseable spans for TipTap
      if (editor) {
        editor.commands.setContent(convertEntitiesToRawBrackets(rawHtmlContent));
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
      // Preprocess to convert &#91; and &#93; entities back to parseable spans for TipTap
      if (editor) {
        editor.commands.setContent(convertEntitiesToRawBrackets(content));
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

  if (!canAccess) {
    return (
      <div style={{ padding: '20px', maxWidth: '800px', margin: '0 auto' }}>
        <h1>{pageTitle}</h1>
        <p style={{ color: '#c75050' }}>Please log in to use the drafts editor.</p>
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
    <div style={{ display: 'flex', gap: '20px', padding: '20px' }}>
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
      <div style={{
        width: sidebarCollapsed ? '40px' : '280px',
        flexShrink: 0,
        transition: 'width 0.2s ease',
        borderRight: '1px solid #ddd',
        paddingRight: sidebarCollapsed ? '0' : '15px'
      }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '15px' }}>
          {!sidebarCollapsed && <h3 style={{ margin: 0, color: '#38495e' }}>Your Drafts</h3>}
          <button
            onClick={() => setSidebarCollapsed(!sidebarCollapsed)}
            style={{ padding: '4px 8px', backgroundColor: '#f8f9f9', border: '1px solid #ccc', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
            title={sidebarCollapsed ? 'Expand sidebar' : 'Collapse sidebar'}
          >
            {sidebarCollapsed ? '>' : '<'}
          </button>
        </div>

        {!sidebarCollapsed && (
          <>
            {/* Search bar */}
            <div style={{ marginBottom: '12px', position: 'relative' }}>
              <input
                type="text"
                value={searchQuery}
                onChange={handleSearchChange}
                placeholder="Search drafts..."
                style={{
                  width: '100%',
                  padding: '8px 10px',
                  paddingRight: searching ? '30px' : '10px',
                  border: '1px solid #ccc',
                  borderRadius: '4px',
                  fontSize: '13px',
                  boxSizing: 'border-box'
                }}
              />
              {searching && (
                <span style={{
                  position: 'absolute',
                  right: '10px',
                  top: '50%',
                  transform: 'translateY(-50%)',
                  color: '#888',
                  fontSize: '11px'
                }}>...</span>
              )}
            </div>

            {/* Show search results or regular drafts list */}
            {searchResults !== null ? (
              // Search results mode
              <>
                <div style={{ fontSize: '11px', color: '#666', marginBottom: '8px' }}>
                  {searchResults.length === 0
                    ? 'No drafts found'
                    : `Found ${searchResults.length} draft${searchResults.length === 1 ? '' : 's'}`}
                </div>
                <div style={{ maxHeight: '500px', overflowY: 'auto' }}>
                  {searchResults.map((draft) => (
                    <div
                      key={draft.node_id}
                      style={{
                        padding: '10px',
                        marginBottom: '8px',
                        backgroundColor: selectedDraft?.node_id === draft.node_id ? '#e8f4f8' : '#f8f9f9',
                        border: selectedDraft?.node_id === draft.node_id ? '1px solid #3bb5c3' : '1px solid #ddd',
                        borderRadius: '4px',
                        transition: 'all 0.15s ease'
                      }}
                    >
                      <div
                        onClick={() => loadDraft(draft)}
                        style={{ cursor: 'pointer' }}
                      >
                        <div style={{ fontWeight: '500', color: '#111', marginBottom: '4px', fontSize: '14px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                          {draft.title}
                        </div>
                        <div style={{ fontSize: '11px', color: '#666', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
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
                          style={{
                            marginTop: '6px',
                            padding: '3px 8px',
                            backgroundColor: 'transparent',
                            color: '#c75050',
                            border: '1px solid #c75050',
                            borderRadius: '3px',
                            cursor: 'pointer',
                            fontSize: '11px'
                          }}
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
                  style={{ marginTop: '10px', padding: '8px 12px', backgroundColor: '#f8f9f9', color: '#555', border: '1px solid #ccc', borderRadius: '4px', cursor: 'pointer', fontSize: '13px', width: '100%' }}
                >
                  Clear Search
                </button>
              </>
            ) : drafts.length === 0 ? (
              <p style={{ color: '#888', fontSize: '14px' }}>No drafts yet. Your drafts will appear here.</p>
            ) : (
              <>
                <div style={{ maxHeight: '500px', overflowY: 'auto' }}>
                  {drafts.map((draft) => (
                    <div
                      key={draft.node_id}
                      style={{
                        padding: '10px',
                        marginBottom: '8px',
                        backgroundColor: selectedDraft?.node_id === draft.node_id ? '#e8f4f8' : '#f8f9f9',
                        border: selectedDraft?.node_id === draft.node_id ? '1px solid #3bb5c3' : '1px solid #ddd',
                        borderRadius: '4px',
                        transition: 'all 0.15s ease'
                      }}
                    >
                      <div
                        onClick={() => loadDraft(draft)}
                        style={{ cursor: 'pointer' }}
                      >
                        <div style={{ fontWeight: '500', color: '#111', marginBottom: '4px', fontSize: '14px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                          {draft.title}
                        </div>
                        <div style={{ fontSize: '11px', color: '#666', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
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
                          style={{
                            marginTop: '6px',
                            padding: '3px 8px',
                            backgroundColor: 'transparent',
                            color: '#c75050',
                            border: '1px solid #c75050',
                            borderRadius: '3px',
                            cursor: 'pointer',
                            fontSize: '11px'
                          }}
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
                    style={{
                      marginTop: '10px',
                      padding: '8px 12px',
                      backgroundColor: loadingMore ? '#999' : '#f8f9f9',
                      color: loadingMore ? '#fff' : '#555',
                      border: '1px solid #ccc',
                      borderRadius: '4px',
                      cursor: loadingMore ? 'wait' : 'pointer',
                      fontSize: '13px',
                      width: '100%'
                    }}
                  >
                    {loadingMore ? 'Loading...' : 'Load More Drafts'}
                  </button>
                )}
              </>
            )}

            {!isReadOnly && (
              <button
                onClick={clearEditor}
                style={{ marginTop: '10px', padding: '8px 12px', backgroundColor: '#4060b0', color: '#fff', border: 'none', borderRadius: '4px', cursor: 'pointer', fontSize: '13px', width: '100%' }}
              >
                + New Draft
              </button>
            )}
          </>
        )}
      </div>

      {/* Main Editor Area */}
      <div style={{ flex: 1, maxWidth: '900px' }}>
        {/* Inject styles for animations and toggle */}
        <style>{editorStyles}</style>

        {/* Header with mode toggle in upper right */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '20px' }}>
          <div>
            <h1 style={{ marginBottom: '10px' }}>{pageTitle}</h1>
            {isReadOnly ? (
              <p style={{ color: '#507898', marginBottom: '0' }}>
                Viewing <a href={`/user/${encodeURIComponent(targetUser?.title)}`} style={{ color: '#4060b0' }}>{targetUser?.title}</a>'s findable drafts (read-only)
              </p>
            ) : (
              <p style={{ color: '#507898', marginBottom: '0' }}>
                Hello, {username}!
              </p>
            )}
          </div>

          {/* Stylized slider toggle - Rich/HTML */}
          <div
            className="e2-mode-toggle"
            onClick={toggleEditMode}
            title={editMode === 'rich' ? 'Switch to raw HTML editing' : 'Switch to rich text editing'}
          >
            <div
              className="e2-mode-toggle-slider"
              style={{
                left: editMode === 'rich' ? '3px' : 'calc(50% + 1px)',
                width: editMode === 'rich' ? '52px' : '52px'
              }}
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
        <div style={{ marginBottom: '15px' }}>
          <input
            type="text"
            value={draftTitle}
            onChange={(e) => !isReadOnly && setDraftTitle(e.target.value)}
            readOnly={isReadOnly}
            placeholder={isReadOnly ? '' : 'Enter draft title...'}
            style={{
              width: '100%',
              padding: '10px 12px',
              border: '1px solid #ccc',
              borderRadius: '4px',
              fontSize: '16px',
              fontWeight: '500',
              backgroundColor: isReadOnly ? '#f8f9f9' : '#fff'
            }}
          />
        </div>

        {/* Toolbar row */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '8px' }}>
          {/* Menu bar - only show in rich mode */}
          {editMode === 'rich' && editor && (
            <div style={{ flex: 1 }}>
              <MenuBar editor={editor} />
            </div>
          )}

          {/* HTML mode indicator */}
          {editMode === 'html' && (
            <span style={{ fontSize: '12px', color: '#666' }}>
              Editing raw HTML — E2 link syntax: [node name] or [node name|display text]
            </span>
          )}
        </div>

        {/* Editor - Rich text or HTML textarea based on mode */}
        {editMode === 'rich' ? (
          <div style={{ border: '1px solid #38495e', borderRadius: '4px', backgroundColor: '#fff' }}>
            <div
              className="e2-editor-wrapper"
              style={{ minHeight: '400px' }}
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
            style={{
              width: '100%',
              minHeight: '400px',
              padding: '12px',
              border: '1px solid #ccc',
              borderRadius: '4px',
              fontFamily: 'monospace',
              fontSize: '13px',
              lineHeight: '1.5',
              resize: 'vertical',
              boxSizing: 'border-box',
              backgroundColor: isReadOnly ? '#f8f9f9' : '#fff'
            }}
            spellCheck={false}
            placeholder={isReadOnly ? '' : 'Enter HTML content here...'}
          />
        )}

        {/* Bottom bar: Controls (left) | Status dropdown + actions (right) */}
        <div style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          marginTop: '8px',
          minHeight: '36px'
        }}>
          {/* Left side: Version History button + Save status */}
          <div style={{
            fontSize: '12px',
            color: '#666',
            display: 'flex',
            alignItems: 'center',
            gap: '10px'
          }}>
            {/* Version History button - styled consistently (hidden in read-only mode) */}
            {selectedDraft && !isReadOnly && (
              <button
                onClick={() => setShowVersionHistory(true)}
                style={{
                  padding: '6px 12px',
                  backgroundColor: '#f8f9f9',
                  border: '1px solid #ccc',
                  borderRadius: '4px',
                  color: '#555',
                  cursor: 'pointer',
                  fontSize: '12px'
                }}
              >
                Version History
              </button>
            )}

            {/* Save status indicator - to the right of Version History (hidden in read-only mode) */}
            {!isReadOnly && (
              <div style={{ display: 'flex', alignItems: 'center', minWidth: '120px' }}>
                {saving ? (
                  <>
                    <SaveSpinner />
                    <span style={{ color: '#4060b0' }}>Saving...</span>
                  </>
                ) : lastSaveTime ? (
                  <span style={{ color: '#666' }}>
                    {lastSaveType === 'auto' ? 'Autosaved' : 'Saved'} at {lastSaveTime}
                  </span>
                ) : null}
              </div>
            )}
          </div>

          {/* Controls - bottom right */}
          <div style={{ display: 'flex', gap: '10px', alignItems: 'center' }}>
            {/* Status dropdown - only when not read-only */}
            {!isReadOnly && (
              <select
                value={draftStatus}
                onChange={(e) => setDraftStatus(e.target.value)}
                style={{
                  padding: '6px 10px',
                  border: '1px solid #ccc',
                  borderRadius: '4px',
                  fontSize: '13px',
                  backgroundColor: '#fff',
                  color: '#333',
                  cursor: 'pointer'
                }}
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
              style={{
                padding: '6px 14px',
                backgroundColor: showPreview ? '#38495e' : '#f8f9f9',
                color: showPreview ? '#fff' : '#111',
                border: '1px solid #38495e',
                borderRadius: '4px',
                cursor: 'pointer',
                fontSize: '13px'
              }}
            >
              {showPreview ? 'Hide Preview' : 'Preview'}
            </button>

            {/* Save button - only when not read-only */}
            {!isReadOnly && (
              <button
                onClick={saveDraft}
                disabled={saving}
                style={{
                  padding: '6px 16px',
                  backgroundColor: saving ? '#999' : '#4060b0',
                  color: '#fff',
                  border: 'none',
                  borderRadius: '4px',
                  cursor: saving ? 'wait' : 'pointer',
                  fontSize: '13px',
                  fontWeight: '500'
                }}
              >
                {saving ? 'Saving...' : (selectedDraft ? 'Save' : 'Create Draft')}
              </button>
            )}

          </div>
        </div>

        {/* Publish section - only visible when editing a saved draft (and not in read-only mode) */}
        {selectedDraft && !isReadOnly && (
          <div style={{ marginTop: '15px', paddingTop: '15px', borderTop: '1px solid #eee' }}>
            <button
              onClick={() => setShowPublishModal(true)}
              disabled={saving}
              style={{
                padding: '8px 20px',
                backgroundColor: saving ? '#999' : '#4060b0',
                color: '#fff',
                border: 'none',
                borderRadius: '4px',
                cursor: saving ? 'wait' : 'pointer',
                fontSize: '14px',
                fontWeight: '500'
              }}
            >
              Publish...
            </button>
            <span style={{ marginLeft: '10px', fontSize: '12px', color: '#888' }}>
              Ready to publish this draft as a writeup
            </span>
          </div>
        )}

        {/* Live preview pane */}
        {showPreview && (
          <div style={{ marginTop: '20px' }}>
            <h3 style={{ marginBottom: '10px', color: '#38495e', fontSize: '14px' }}>Preview</h3>
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
