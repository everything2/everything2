import React, { useState, useCallback, useEffect, useRef, useMemo } from 'react';
import { useEditor, EditorContent } from '@tiptap/react';
import { getE2EditorExtensions } from './Editor/useE2Editor';
import { convertToE2Syntax } from './Editor/E2LinkExtension';
import { convertRawBracketsToEntities, convertEntitiesToRawBrackets } from './Editor/RawBracketExtension';
import { renderE2Content } from './Editor/E2HtmlSanitizer';
import MenuBar from './Editor/MenuBar';
import { useWriteuptypes } from '../hooks/usePublishDraft';
import { fetchWithErrorReporting } from '../utils/reportClientError';
import './Editor/E2Editor.css';

/**
 * InlineWriteupEditor - Inline Tiptap editor for creating/editing writeups on e2node pages
 *
 * Features:
 * - Tiptap WYSIWYG editor (Rich mode)
 * - HTML/Rich mode toggle with preference persistence
 * - Autosave (creates draft on first keystroke, saves every 3 seconds)
 * - Publish button (converts draft to writeup)
 * - Inline display (no navigation away from page)
 *
 * Props:
 * - e2nodeId: The parent e2node ID
 * - e2nodeTitle: The parent e2node title
 * - initialContent: Optional initial HTML content (for editing existing writeup)
 * - draftId: Optional existing draft ID
 * - writeupId: Optional existing writeup ID (for editing published writeup)
 * - writeupAuthor: Optional author name (for editing - shows "Editing X's writeup")
 * - isOwnWriteup: Optional boolean - true if current user owns this writeup
 * - onPublish: Callback after successful publication
 * - onSave: Callback after successful save (for edit mode)
 * - onCancel: Callback when editor is cancelled
 */

// Get initial editor mode from localStorage (same preference as E2 Editor Beta)
const getInitialEditorMode = () => {
  try {
    const stored = localStorage.getItem('e2_editor_mode');
    if (stored === 'html') return 'html';
  } catch (e) {
    // localStorage may not be available
  }
  return 'rich';
};

const InlineWriteupEditor = ({
  e2nodeId,
  e2nodeTitle,
  initialContent = '',
  draftId: initialDraftId = null,
  writeupId = null,
  writeupAuthor = null,
  isOwnWriteup = false,
  onPublish = () => {},
  onSave = () => {},
  onCancel = () => {}
}) => {
  const [editorMode, setEditorMode] = useState(getInitialEditorMode); // 'rich' or 'html'
  const [htmlContent, setHtmlContent] = useState(initialContent);
  const [draftId, setDraftId] = useState(initialDraftId);
  const [saveStatus, setSaveStatus] = useState('saved'); // 'saved', 'saving', 'unsaved'
  const [publishing, setPublishing] = useState(false);
  const [errorMessage, setErrorMessage] = useState(null);
  const [hideFromNewWriteups, setHideFromNewWriteups] = useState(false);
  const [showPreview, setShowPreview] = useState(true); // Live preview toggle
  const [previewTrigger, setPreviewTrigger] = useState(0); // Trigger preview updates
  const autosaveTimerRef = useRef(null);
  const firstEditRef = useRef(false);

  // Use shared writeuptypes hook (skip for editing existing writeups)
  const {
    writeuptypes,
    selectedWriteuptypeId,
    setSelectedWriteuptypeId
  } = useWriteuptypes({ skip: !!writeupId });

  // Initialize Tiptap editor
  // Preprocess to convert &#91; and &#93; entities back to parseable spans for TipTap
  const editor = useEditor({
    extensions: getE2EditorExtensions(),
    content: convertEntitiesToRawBrackets(initialContent),
    onUpdate: ({ editor: updatedEditor }) => {
      // Mark as unsaved
      setSaveStatus('unsaved');

      // Trigger preview update
      setPreviewTrigger(prev => prev + 1);

      // Skip autosave when editing existing writeup - only manual Update
      if (writeupId) return;

      // Create draft on first edit (new writeup only)
      if (!firstEditRef.current && !draftId) {
        firstEditRef.current = true;
        createDraft(updatedEditor.getHTML());
      }

      // Schedule autosave for drafts only
      if (autosaveTimerRef.current) {
        clearTimeout(autosaveTimerRef.current);
      }

      autosaveTimerRef.current = setTimeout(() => {
        const content = updatedEditor.getHTML();
        saveDraft(content);
      }, 3000); // Autosave after 3 seconds of inactivity
    }
  });

  // Cleanup autosave timer on unmount
  useEffect(() => {
    return () => {
      if (autosaveTimerRef.current) {
        clearTimeout(autosaveTimerRef.current);
      }
    };
  }, []);

  // Create a new draft
  const createDraft = async (content) => {
    // Convert raw bracket spans to HTML entities before saving
    const processedContent = convertRawBracketsToEntities(content);

    try {
      const response = await fetch('/api/drafts', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({
          title: e2nodeTitle,
          doctext: processedContent
        })
      });

      const result = await response.json();
      if (result.success) {
        setDraftId(result.draft.node_id);
        setSaveStatus('saved');
      } else {
        setErrorMessage(`Failed to create draft: ${result.error}`);
      }
    } catch (err) {
      setErrorMessage(`Error creating draft: ${err.message}`);
    }
  };

  // Save draft content
  const saveDraft = async (content) => {
    if (!draftId && !writeupId) return;

    setSaveStatus('saving');

    // Convert raw bracket spans to HTML entities before saving
    // This ensures [text] in the editor saves as &#91;text&#93; in the database
    const processedContent = convertRawBracketsToEntities(content);

    try {
      const endpoint = writeupId
        ? `/api/writeups/${writeupId}/action/update`
        : `/api/drafts/${draftId}`;

      const response = await fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({
          doctext: processedContent
        })
      });

      const result = await response.json();
      if (result.success) {
        setSaveStatus('saved');
        setErrorMessage(null);
      } else {
        setSaveStatus('unsaved');
        setErrorMessage(`Save failed: ${result.error}`);
      }
    } catch (err) {
      setSaveStatus('unsaved');
      setErrorMessage(`Save error: ${err.message}`);
    }
  };

  // Publish draft
  const handlePublish = async () => {
    if (!draftId) {
      setErrorMessage('No draft to publish');
      return;
    }

    setPublishing(true);
    setErrorMessage(null);

    try {
      // Save current content to draft before publishing
      const content = editorMode === 'rich' ? editor.getHTML() : htmlContent;
      await saveDraft(content);

      // Validate writeuptype selection
      if (!selectedWriteuptypeId) {
        setErrorMessage('Please select a writeup type');
        setPublishing(false);
        return;
      }

      // Publish draft (using node_id from dropdown)
      const response = await fetchWithErrorReporting(
        `/api/drafts/${draftId}/publish`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          credentials: 'include',
          body: JSON.stringify({
            parent_e2node: e2nodeId,
            wrtype_writeuptype: selectedWriteuptypeId,
            feedback_policy_id: 0,
            notnew: hideFromNewWriteups ? 1 : 0
          })
        },
        'publishing draft'
      );

      const result = await response.json();
      if (result.success) {
        onPublish(result.writeup_id);
        // Reload page to show new writeup
        window.location.reload();
      } else {
        setErrorMessage(`Publish failed: ${result.error || result.message}`);
        setPublishing(false);
      }
    } catch (err) {
      setErrorMessage(`Publish error: ${err.message}`);
      setPublishing(false);
    }
  };

  // Toggle between Rich and HTML mode
  const handleModeToggle = () => {
    const newMode = editorMode === 'rich' ? 'html' : 'rich';

    if (editorMode === 'rich') {
      // Switch to HTML mode - convert Tiptap content to E2 syntax
      const html = editor.getHTML();
      const e2Html = convertToE2Syntax(html);
      const cleanedHtml = convertRawBracketsToEntities(e2Html);
      setHtmlContent(cleanedHtml);
    } else {
      // Switch to Rich mode - update editor with HTML content
      // Preprocess to convert &#91; and &#93; entities back to parseable spans for TipTap
      editor.commands.setContent(convertEntitiesToRawBrackets(htmlContent));
    }

    setEditorMode(newMode);

    // Save preference to localStorage
    try {
      localStorage.setItem('e2_editor_mode', newMode);
    } catch (e) {
      // localStorage may not be available
    }

    // Save preference to server (same as E2 Editor Beta)
    fetch('/api/preferences/set', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify({ tiptap_editor_raw: newMode === 'html' ? 1 : 0 })
    }).catch(err => console.error('Failed to save editor mode preference:', err));
  };

  // Update HTML content in textarea
  const handleHtmlChange = (e) => {
    const newHtml = e.target.value;
    setHtmlContent(newHtml);
    setSaveStatus('unsaved');
    setPreviewTrigger(prev => prev + 1);

    // Skip autosave when editing existing writeup - only manual Update
    if (writeupId) return;

    // Schedule autosave for drafts only
    if (autosaveTimerRef.current) {
      clearTimeout(autosaveTimerRef.current);
    }

    autosaveTimerRef.current = setTimeout(() => {
      saveDraft(newHtml);
    }, 3000);
  };

  // Manual save handler for drafts
  const handleManualSave = async () => {
    if (!draftId && !writeupId) return;
    const content = editorMode === 'rich' ? editor.getHTML() : htmlContent;
    await saveDraft(content);
  };

  const getSaveStatusText = () => {
    // If editing existing writeup, show different status
    if (writeupId) {
      switch (saveStatus) {
        case 'saving':
          return 'Saving...';
        case 'unsaved':
          return 'Unsaved changes - click Update to save';
        case 'saved':
          return '';
        default:
          return '';
      }
    }

    // If no draft exists yet, don't show "All changes saved"
    if (!draftId && saveStatus === 'saved') {
      return 'Start typing to create a draft';
    }

    switch (saveStatus) {
      case 'saving':
        return 'Saving...';
      case 'unsaved':
        return 'Unsaved changes';
      case 'saved':
        return (
          <span>
            All changes saved to{' '}
            <a href="/title/Drafts" style={{ color: '#4060b0' }}>Drafts</a>
          </span>
        );
      default:
        return '';
    }
  };

  return (
    <div className="inline-writeup-editor" style={{
      border: '1px solid #ccc',
      borderRadius: '4px',
      padding: '12px',
      marginTop: '20px',
      backgroundColor: '#f9f9f9'
    }}>
      {/* Editor header - title and mode toggle */}
      <div style={{
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'flex-start',
        marginBottom: '10px'
      }}>
        {/* Title section */}
        <div>
          <h3 style={{ margin: 0, fontSize: '16px', fontWeight: '600' }}>
            {writeupId
              ? (isOwnWriteup ? 'Editing your writeup' : `Editing ${writeupAuthor}'s writeup`)
              : (initialDraftId ? 'Continue your draft' : 'Add a Writeup')}
          </h3>
          {!writeupId && (
            <span style={{ fontSize: '12px', color: '#666' }}>
              to "{e2nodeTitle}"
            </span>
          )}
        </div>
        {/* Mode toggle - uses shared CSS from E2Editor.css */}
        <div
          className="e2-mode-toggle"
          onClick={handleModeToggle}
          title={editorMode === 'rich' ? 'Switch to raw HTML editing' : 'Switch to rich text editing'}
        >
          <div className={`e2-mode-toggle-option ${editorMode === 'rich' ? 'active' : ''}`}
               style={{ backgroundColor: editorMode === 'rich' ? '#4060b0' : 'transparent' }}>
            Rich
          </div>
          <div className={`e2-mode-toggle-option ${editorMode === 'html' ? 'active' : ''}`}
               style={{ backgroundColor: editorMode === 'html' ? '#4060b0' : 'transparent' }}>
            HTML
          </div>
        </div>
      </div>

      {/* Error message */}
      {errorMessage && (
        <div style={{
          padding: '8px',
          marginBottom: '10px',
          backgroundColor: '#fee',
          border: '1px solid #fcc',
          borderRadius: '4px',
          color: '#c00',
          fontSize: '13px'
        }}>
          {errorMessage}
        </div>
      )}

      {/* Editor content */}
      {editorMode === 'rich' ? (
        <div style={{ border: '1px solid #ccc', borderRadius: '4px', backgroundColor: '#fff' }}>
          <MenuBar editor={editor} />
          <div
            style={{ minHeight: '200px', padding: '12px', cursor: 'text' }}
            onClick={(e) => {
              // Only focus editor when clicking directly on the padding area, not on text
              // This prevents interfering with text selection inside the editor
              if (e.target === e.currentTarget) {
                editor?.commands.focus();
              }
            }}
          >
            <EditorContent editor={editor} />
          </div>
        </div>
      ) : (
        <textarea
          value={htmlContent}
          onChange={handleHtmlChange}
          placeholder="Enter HTML content here..."
          style={{
            width: '100%',
            minHeight: '200px',
            fontFamily: 'monospace',
            fontSize: '13px',
            padding: '12px',
            border: '1px solid #ccc',
            borderRadius: '4px',
            backgroundColor: '#fff',
            color: '#333',
            lineHeight: '1.5',
            resize: 'vertical',
            boxSizing: 'border-box'
          }}
          spellCheck={false}
        />
      )}

      {/* Footer with save status and actions */}
      <div style={{ marginTop: '10px' }}>
        {/* First row: status and Cancel/Save buttons */}
        <div style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          flexWrap: 'wrap',
          gap: '10px'
        }}>
          <div style={{ fontSize: '12px', color: '#666' }}>
            {getSaveStatusText()}
          </div>

          <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end' }}>
            <button
              onClick={onCancel}
              disabled={publishing}
              style={{
                padding: '6px 16px',
                fontSize: '13px',
                border: '1px solid #ccc',
                borderRadius: '4px',
                background: '#fff',
                cursor: publishing ? 'not-allowed' : 'pointer',
                opacity: publishing ? 0.5 : 1
              }}
            >
              Cancel
            </button>

            {/* Save button for drafts (new writeups) */}
            {!writeupId && (
              <button
                onClick={handleManualSave}
                disabled={!draftId || publishing || saveStatus === 'saving'}
                style={{
                  padding: '6px 16px',
                  fontSize: '13px',
                  border: '1px solid #4060b0',
                  borderRadius: '4px',
                  background: '#fff',
                  color: (!draftId || publishing || saveStatus === 'saving') ? '#999' : '#4060b0',
                  cursor: (!draftId || publishing || saveStatus === 'saving') ? 'not-allowed' : 'pointer',
                  fontWeight: '500'
                }}
              >
                {saveStatus === 'saving' ? 'Saving...' : 'Save'}
              </button>
            )}

            {/* Update button for editing existing writeups */}
            {writeupId && (
              <button
                onClick={async () => {
                  // Get current content
                  const content = editorMode === 'rich'
                    ? convertToE2Syntax(convertRawBracketsToEntities(editor.getHTML()))
                    : htmlContent;

                  // Save the content
                  await saveDraft(content);

                  // Call onSave with the new content so parent can update display
                  onSave(content);
                }}
                disabled={saveStatus === 'saving'}
                style={{
                  padding: '6px 16px',
                  fontSize: '13px',
                  border: 'none',
                  borderRadius: '4px',
                  background: saveStatus === 'saving' ? '#ccc' : '#4060b0',
                  color: '#fff',
                  cursor: saveStatus === 'saving' ? 'not-allowed' : 'pointer',
                  fontWeight: '500'
                }}
              >
                {saveStatus === 'saving' ? 'Saving...' : 'Update'}
              </button>
            )}
          </div>
        </div>

        {/* Second row: Writeuptype selector, hide checkbox, and Publish button (new writeups only) */}
        {!writeupId && (
          <div style={{
            display: 'flex',
            justifyContent: 'flex-end',
            alignItems: 'center',
            gap: '8px',
            marginTop: '10px',
            flexWrap: 'wrap'
          }}>
            <span style={{ fontSize: '13px', color: '#666' }}>Publish as:</span>
            <select
              value={selectedWriteuptypeId || ''}
              onChange={(e) => setSelectedWriteuptypeId(Number(e.target.value))}
              disabled={!draftId || publishing || saveStatus === 'saving'}
              style={{
                padding: '6px 10px',
                fontSize: '13px',
                border: '1px solid #ccc',
                borderRadius: '4px',
                background: '#fff',
                cursor: (!draftId || publishing || saveStatus === 'saving') ? 'not-allowed' : 'pointer',
                opacity: (!draftId || publishing || saveStatus === 'saving') ? 0.5 : 1
              }}
            >
              {writeuptypes.length > 0 ? (
                writeuptypes.map(wt => (
                  <option key={wt.node_id} value={wt.node_id}>{wt.title}</option>
                ))
              ) : (
                <option value="">Loading...</option>
              )}
            </select>
            <label style={{
              display: 'flex',
              alignItems: 'center',
              fontSize: '12px',
              color: '#666',
              cursor: 'pointer'
            }}>
              <input
                type="checkbox"
                checked={hideFromNewWriteups}
                onChange={(e) => setHideFromNewWriteups(e.target.checked)}
                style={{ marginRight: '4px' }}
              />
              Hide from New Writeups
            </label>
            <button
              onClick={handlePublish}
              disabled={!draftId || publishing || saveStatus === 'saving'}
              style={{
                padding: '6px 16px',
                fontSize: '13px',
                border: 'none',
                borderRadius: '4px',
                background: (!draftId || publishing || saveStatus === 'saving') ? '#ccc' : '#4060b0',
                color: '#fff',
                cursor: (!draftId || publishing || saveStatus === 'saving') ? 'not-allowed' : 'pointer',
                fontWeight: '500'
              }}
            >
              {publishing ? 'Publishing...' : 'Publish'}
            </button>
          </div>
        )}
      </div>

      {/* Live Preview Section */}
      <div style={{ marginTop: '16px', borderTop: '1px solid #ddd', paddingTop: '12px' }}>
        <div style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          marginBottom: '8px'
        }}>
          <h4 style={{ margin: 0, fontSize: '14px', color: '#666', fontWeight: '500' }}>
            Preview
          </h4>
          <button
            onClick={() => setShowPreview(!showPreview)}
            style={{
              background: 'none',
              border: '1px solid #ccc',
              borderRadius: '4px',
              padding: '2px 8px',
              fontSize: '11px',
              color: '#666',
              cursor: 'pointer'
            }}
          >
            {showPreview ? 'Hide' : 'Show'}
          </button>
        </div>
        {showPreview && (
          <PreviewContent
            editor={editor}
            editorMode={editorMode}
            htmlContent={htmlContent}
            previewTrigger={previewTrigger}
          />
        )}
      </div>
    </div>
  );
};

/**
 * PreviewContent - Renders live preview of editor content
 * Updates on each editor change via previewTrigger
 */
const PreviewContent = ({ editor, editorMode, htmlContent, previewTrigger }) => {
  // Get current content from editor or HTML textarea
  // previewTrigger forces re-computation when editor content changes
  const currentContent = useMemo(() => {
    if (editorMode === 'html') {
      return htmlContent;
    }
    if (editor) {
      const html = editor.getHTML();
      const withEntities = convertRawBracketsToEntities(html);
      return convertToE2Syntax(withEntities);
    }
    return '';
  }, [editor, editorMode, htmlContent, previewTrigger]);

  // Render through E2 sanitizer with link parsing
  const renderedContent = useMemo(() => {
    if (!currentContent) return '';
    const { html } = renderE2Content(currentContent);
    return html;
  }, [currentContent]);

  if (!currentContent) {
    return (
      <div style={{
        padding: '20px',
        backgroundColor: '#fff',
        border: '1px solid #e0e0e0',
        borderRadius: '4px',
        color: '#999',
        fontStyle: 'italic',
        textAlign: 'center'
      }}>
        Start typing to see preview...
      </div>
    );
  }

  return (
    <div
      className="content"
      style={{
        padding: '12px',
        backgroundColor: '#fff',
        border: '1px solid #e0e0e0',
        borderRadius: '4px',
        lineHeight: '1.6'
      }}
      dangerouslySetInnerHTML={{ __html: renderedContent }}
    />
  );
};

export default InlineWriteupEditor;
