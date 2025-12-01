import React, { useState, useCallback, useEffect, useRef } from 'react';
import { useEditor, EditorContent } from '@tiptap/react';
import StarterKit from '@tiptap/starter-kit';
import Underline from '@tiptap/extension-underline';
import Subscript from '@tiptap/extension-subscript';
import Superscript from '@tiptap/extension-superscript';
import Table from '@tiptap/extension-table';
import TableRow from '@tiptap/extension-table-row';
import TableCell from '@tiptap/extension-table-cell';
import TableHeader from '@tiptap/extension-table-header';
import { E2Link, convertToE2Syntax } from '../Editor/E2LinkExtension';
import { renderE2Content } from '../Editor/E2HtmlSanitizer';
import MenuBar from '../Editor/MenuBar';
import '../Editor/E2Editor.css';

// Inline styles for animations
const editorStyles = `
  @keyframes e2-spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }

  .e2-mode-toggle {
    display: flex;
    align-items: center;
    background: #e8e8e8;
    border-radius: 20px;
    padding: 3px;
    position: relative;
    cursor: pointer;
    user-select: none;
  }

  .e2-mode-toggle-option {
    padding: 5px 14px;
    font-size: 12px;
    font-weight: 500;
    color: #666;
    border-radius: 17px;
    transition: all 0.2s ease;
    z-index: 1;
    position: relative;
  }

  .e2-mode-toggle-option.active {
    color: #fff;
  }

  .e2-mode-toggle-slider {
    position: absolute;
    top: 3px;
    height: calc(100% - 6px);
    background: #4060b0;
    border-radius: 17px;
    transition: all 0.2s ease;
    z-index: 0;
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
  const { approvedTags, canAccess, username, drafts: initialDrafts, statuses = [] } = data || {};
  // Handle null/undefined drafts gracefully
  const safeDrafts = initialDrafts || [];

  // State
  const [showPreview, setShowPreview] = useState(false);
  const [showHtml, setShowHtml] = useState(false);
  const [copied, setCopied] = useState(false);
  const [selectedDraft, setSelectedDraft] = useState(null);
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);
  const [drafts, setDrafts] = useState(safeDrafts);
  const [draftTitle, setDraftTitle] = useState('');
  const [draftStatus, setDraftStatus] = useState('private');
  const [saving, setSaving] = useState(false);
  const [previewHtml, setPreviewHtml] = useState('');
  const [previewLoading, setPreviewLoading] = useState(false);
  const [lastSaveTime, setLastSaveTime] = useState(null);
  const [lastSaveType, setLastSaveType] = useState(null); // 'manual' or 'auto'
  const [showVersionHistory, setShowVersionHistory] = useState(false);
  const [editMode, setEditMode] = useState('rich'); // 'rich' or 'html'
  const [rawHtmlContent, setRawHtmlContent] = useState('');

  // Refs for autosave
  const autosaveTimerRef = useRef(null);
  const lastSavedContentRef = useRef('');

  const defaultContent = `
    <h2>Welcome to the E2 Editor Beta</h2>
    <p>This is a <strong>test page</strong> for the new <em>Tiptap-based</em> editor.</p>
    <p>Try out these features:</p>
    <ul>
      <li>Bold, italic, underline, strikethrough</li>
      <li>Headings (h1-h6)</li>
      <li>Lists (ordered and unordered)</li>
      <li>Blockquotes</li>
      <li>Code blocks</li>
      <li>Tables</li>
      <li>E2 links: [Test Node]</li>
    </ul>
    <p>The editor enforces E2's approved HTML tags through its schema.</p>
  `;

  const editor = useEditor({
    extensions: [
      StarterKit.configure({
        heading: { levels: [1, 2, 3, 4, 5, 6] }
      }),
      Underline,
      Subscript,
      Superscript,
      Table.configure({ resizable: false }),
      TableRow,
      TableCell,
      TableHeader,
      E2Link
    ],
    content: defaultContent,
    editorProps: {
      attributes: {
        class: 'e2-editor-content',
        spellcheck: 'true'
      }
    }
  });

  // Get current content from either rich editor or raw HTML textarea
  const getCurrentContent = useCallback(() => {
    if (editMode === 'html') {
      return rawHtmlContent;
    }
    return editor ? convertToE2Syntax(editor.getHTML()) : '';
  }, [editor, editMode, rawHtmlContent]);

  // Toggle between rich and HTML editing modes
  const toggleEditMode = useCallback(() => {
    if (editMode === 'rich') {
      // Switching to HTML mode - capture current rich content
      const html = editor ? convertToE2Syntax(editor.getHTML()) : '';
      setRawHtmlContent(html);
      setEditMode('html');
    } else {
      // Switching to rich mode - load HTML content into editor
      if (editor) {
        editor.commands.setContent(rawHtmlContent);
      }
      setEditMode('rich');
    }
  }, [editor, editMode, rawHtmlContent]);

  // Client-side preview rendering with E2 link parsing
  // Uses DOMPurify for sanitization - no server round-trip needed
  const renderPreview = useCallback(() => {
    setPreviewLoading(true);
    const html = getCurrentContent();

    // Use client-side sanitization and link parsing
    const { html: renderedHtml } = renderE2Content(html);
    setPreviewHtml(renderedHtml);

    setPreviewLoading(false);
  }, [getCurrentContent]);

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
      const currentContent = editMode === 'html'
        ? rawHtmlContent
        : convertToE2Syntax(editor.getHTML());

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

            // Refresh preview if it's open
            if (showPreview) {
              renderPreview();
            }
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
  }, [editor, selectedDraft, showPreview, renderPreview, editMode, rawHtmlContent]);

  // Copy HTML to clipboard
  const copyHtml = useCallback(() => {
    const e2Html = getCurrentContent();
    navigator.clipboard.writeText(e2Html).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    });
  }, [getCurrentContent]);

  // Load a draft into the editor
  const loadDraft = useCallback((draft) => {
    if (draft) {
      // For empty drafts, set to empty paragraph so editor is usable
      // (empty string '' can cause Tiptap issues)
      const content = draft.doctext || '<p></p>';

      // Load into both rich editor and raw HTML state
      if (editor) {
        editor.commands.setContent(content);
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

        // Refresh preview if it's open
        if (showPreview) {
          renderPreview();
        }
      }
    } catch (err) {
      console.error('Save failed:', err);
    }

    setSaving(false);
  }, [editor, selectedDraft, draftTitle, draftStatus, drafts, showPreview, renderPreview, editMode, getCurrentContent]);

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

  // Toggle preview and fetch rendered HTML
  const togglePreview = useCallback(() => {
    if (!showPreview) {
      renderPreview();
    }
    setShowPreview(!showPreview);
  }, [showPreview, renderPreview]);

  if (!canAccess) {
    return (
      <div style={{ padding: '20px', maxWidth: '800px', margin: '0 auto' }}>
        <h1>E2 Editor Beta</h1>
        <p style={{ color: '#c75050' }}>Please log in to use the editor beta.</p>
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
            {drafts.length === 0 ? (
              <p style={{ color: '#888', fontSize: '14px' }}>No drafts yet. Your drafts will appear here.</p>
            ) : (
              <div style={{ maxHeight: '500px', overflowY: 'auto' }}>
                {drafts.map((draft) => (
                  <div
                    key={draft.node_id}
                    onClick={() => loadDraft(draft)}
                    style={{
                      padding: '10px',
                      marginBottom: '8px',
                      backgroundColor: selectedDraft?.node_id === draft.node_id ? '#e8f4f8' : '#f8f9f9',
                      border: selectedDraft?.node_id === draft.node_id ? '1px solid #3bb5c3' : '1px solid #ddd',
                      borderRadius: '4px',
                      cursor: 'pointer',
                      transition: 'all 0.15s ease'
                    }}
                  >
                    <div style={{ fontWeight: '500', color: '#111', marginBottom: '4px', fontSize: '14px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                      {draft.title}
                    </div>
                    <div style={{ fontSize: '11px', color: '#666', display: 'flex', justifyContent: 'space-between' }}>
                      <span style={{ color: getStatusColor(draft.status) }}>{draft.status}</span>
                      <span>{draft.createtime?.split(' ')[0]}</span>
                    </div>
                  </div>
                ))}
              </div>
            )}

            <button
              onClick={clearEditor}
              style={{ marginTop: '10px', padding: '8px 12px', backgroundColor: '#4060b0', color: '#fff', border: 'none', borderRadius: '4px', cursor: 'pointer', fontSize: '13px', width: '100%' }}
            >
              + New Draft
            </button>
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
            <h1 style={{ marginBottom: '10px' }}>E2 Editor Beta</h1>
            <p style={{ color: '#507898', marginBottom: '0' }}>
              Hello, {username}!
            </p>
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
            onChange={(e) => setDraftTitle(e.target.value)}
            placeholder="Enter draft title..."
            style={{
              width: '100%',
              padding: '10px 12px',
              border: '1px solid #ccc',
              borderRadius: '4px',
              fontSize: '16px',
              fontWeight: '500'
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
            <EditorContent editor={editor} />
          </div>
        ) : (
          <textarea
            value={rawHtmlContent}
            onChange={(e) => setRawHtmlContent(e.target.value)}
            style={{
              width: '100%',
              minHeight: '400px',
              padding: '12px',
              backgroundColor: '#1e1e1e',
              color: '#d4d4d4',
              border: '1px solid #38495e',
              borderRadius: '4px',
              fontFamily: 'monospace',
              fontSize: '13px',
              lineHeight: '1.5',
              resize: 'vertical',
              boxSizing: 'border-box'
            }}
            spellCheck={false}
            placeholder="Enter HTML content here..."
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
            {/* Version History button - styled consistently */}
            {selectedDraft && (
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

            {/* Save status indicator - to the right of Version History */}
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
          </div>

          {/* Controls - bottom right */}
          <div style={{ display: 'flex', gap: '10px', alignItems: 'center' }}>
            {/* Status dropdown */}
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

            {/* Preview button */}
            <button
              onClick={togglePreview}
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
              {previewLoading ? 'Loading...' : (showPreview ? 'Hide Preview' : 'Preview')}
            </button>

            {/* Save button */}
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
          </div>
        </div>

        {/* Preview pane - client-side rendered with E2 links */}
        {showPreview && (
          <div style={{ marginTop: '20px' }}>
            <h3 style={{ marginBottom: '10px', color: '#38495e', fontSize: '14px' }}>Preview</h3>
            <div
              style={{
                padding: '15px',
                border: '1px solid #ccc',
                borderRadius: '4px',
                backgroundColor: '#fafafa'
              }}
              dangerouslySetInnerHTML={{ __html: previewHtml }}
            />
          </div>
        )}

        {/* Divider for less-used features */}
        <div style={{ marginTop: '30px', paddingTop: '20px', borderTop: '1px solid #ddd' }}>
          <h4 style={{ marginBottom: '15px', color: '#666', fontSize: '13px', fontWeight: 'normal' }}>HTML Tools</h4>

          {/* HTML action buttons */}
          <div style={{ display: 'flex', gap: '10px', marginBottom: '15px' }}>
            <button
              onClick={() => setShowHtml(!showHtml)}
              style={{
                padding: '6px 14px',
                backgroundColor: showHtml ? '#38495e' : '#f8f9f9',
                color: showHtml ? '#fff' : '#555',
                border: '1px solid #ccc',
                borderRadius: '4px',
                cursor: 'pointer',
                fontSize: '12px'
              }}
            >
              {showHtml ? 'Hide HTML' : 'Show HTML'}
            </button>

            <button
              onClick={copyHtml}
              style={{
                padding: '6px 14px',
                backgroundColor: copied ? '#4caf50' : '#f8f9f9',
                color: copied ? '#fff' : '#555',
                border: '1px solid #ccc',
                borderRadius: '4px',
                cursor: 'pointer',
                fontSize: '12px'
              }}
            >
              {copied ? 'Copied!' : 'Copy HTML'}
            </button>
          </div>

          {/* HTML output */}
          {showHtml && editor && (
            <div style={{ marginBottom: '20px' }}>
              <textarea
                readOnly
                value={convertToE2Syntax(editor.getHTML())}
                style={{
                  width: '100%',
                  minHeight: '250px',
                  padding: '12px',
                  backgroundColor: '#1e1e1e',
                  color: '#d4d4d4',
                  borderRadius: '4px',
                  border: 'none',
                  fontFamily: 'monospace',
                  fontSize: '12px',
                  lineHeight: '1.5',
                  resize: 'vertical'
                }}
                onClick={(e) => e.target.select()}
              />
            </div>
          )}

          {/* Approved tags reference */}
          <details style={{ marginTop: '15px' }}>
            <summary style={{ cursor: 'pointer', color: '#666', fontSize: '12px', marginBottom: '10px' }}>
              E2 Approved HTML Tags
            </summary>
            <div style={{ padding: '10px', backgroundColor: '#f5f5f5', borderRadius: '4px', fontFamily: 'monospace', fontSize: '11px', lineHeight: '1.8' }}>
              {approvedTags && approvedTags.length > 0
                ? approvedTags.map((tag) => (
                    <span key={tag} style={{ display: 'inline-block', padding: '2px 5px', margin: '2px', backgroundColor: '#e3e3e3', borderRadius: '3px' }}>
                      &lt;{tag}&gt;
                    </span>
                  ))
                : 'Loading tags...'}
            </div>
          </details>
        </div>
      </div>
    </div>
  );
};

export default EditorBeta;
