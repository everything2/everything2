import React, { useState, useCallback, useEffect, useRef } from 'react';
import { useEditor, EditorContent } from '@tiptap/react';
import { getE2EditorExtensions } from './Editor/useE2Editor';
import { convertToE2Syntax } from './Editor/E2LinkExtension';
import { convertRawBracketsToEntities, convertEntitiesToRawBrackets } from './Editor/RawBracketExtension';
import { breakTags } from './Editor/E2HtmlSanitizer';
import MenuBar from './Editor/MenuBar';
import PreviewContent from './Editor/PreviewContent';
import { useWriteuptypes } from '../hooks/usePublishDraft';
import { fetchWithErrorReporting } from '../utils/reportClientError';
import './Editor/E2Editor.css';

/**
 * Parse a draft title to extract e2node title and writeuptype
 * Writeup titles have format: "e2node title (writeuptype)"
 * Returns { e2nodeTitle, writeuptypeName } or just { e2nodeTitle } if no suffix
 */
const parseDraftTitle = (title) => {
  if (!title) return { e2nodeTitle: '' }

  // Match pattern: "some title (writeuptype)" where writeuptype is at the end
  const match = title.match(/^(.+?)\s+\(([^)]+)\)$/)
  if (match) {
    return {
      e2nodeTitle: match[1],
      writeuptypeName: match[2]
    }
  }

  return { e2nodeTitle: title }
}

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
  e2nodeTitle: e2nodeTitleProp,
  initialContent = '',
  draftId: initialDraftId = null,
  writeupId = null,
  writeupAuthor = null,
  isOwnWriteup = false,
  onPublish = () => {},
  onSave = () => {},
  onCancel = () => {}
}) => {
  // Parse the e2nodeTitle to extract actual e2node title and writeuptype (if present)
  const parsedTitle = parseDraftTitle(e2nodeTitleProp)
  const e2nodeTitle = parsedTitle.e2nodeTitle

  const [editorMode, setEditorMode] = useState(getInitialEditorMode); // 'rich' or 'html'
  const [htmlContent, setHtmlContent] = useState(initialContent);
  const [draftId, setDraftId] = useState(initialDraftId);
  const [saveStatus, setSaveStatus] = useState('saved'); // 'saved', 'saving', 'unsaved'
  const [publishing, setPublishing] = useState(false);
  const [errorMessage, setErrorMessage] = useState(null);
  const [hideFromNewWriteups, setHideFromNewWriteups] = useState(false);
  const [showPreview, setShowPreview] = useState(true); // Live preview toggle
  const [previewTrigger, setPreviewTrigger] = useState(0); // Trigger preview updates
  const [resolvedE2nodeId, setResolvedE2nodeId] = useState(e2nodeId); // Resolved e2node ID (from prop or lookup)
  const [e2nodeStatus, setE2nodeStatus] = useState(e2nodeId ? 'found' : 'checking'); // 'checking', 'found', 'not_found'
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false); // Delete confirmation modal
  const [deleting, setDeleting] = useState(false); // Delete in progress
  const autosaveTimerRef = useRef(null);
  const firstEditRef = useRef(false);
  const lastSavedContentRef = useRef(initialContent); // Track last saved content from server
  const hasSetWriteuptypeFromTitleRef = useRef(false); // Track if we've already set writeuptype from title

  // Use shared writeuptypes hook (skip for editing existing writeups)
  const {
    writeuptypes,
    selectedWriteuptypeId,
    setSelectedWriteuptypeId
  } = useWriteuptypes({ skip: !!writeupId });

  // When writeuptypes load, pre-select the one from the title (if any)
  // This overrides the default "thing" selection if we have a writeuptype in the title
  useEffect(() => {
    if (
      parsedTitle.writeuptypeName &&
      writeuptypes.length > 0 &&
      !hasSetWriteuptypeFromTitleRef.current
    ) {
      const matchingType = writeuptypes.find(
        wt => wt.title.toLowerCase() === parsedTitle.writeuptypeName.toLowerCase()
      )
      if (matchingType) {
        hasSetWriteuptypeFromTitleRef.current = true
        setSelectedWriteuptypeId(matchingType.node_id)
      }
    }
  }, [writeuptypes, parsedTitle.writeuptypeName, setSelectedWriteuptypeId])

  // Check if e2node exists when we have a parsed title but no e2nodeId prop
  useEffect(() => {
    if (e2nodeId) {
      // Already have an e2node ID from props
      setResolvedE2nodeId(e2nodeId);
      setE2nodeStatus('found');
      return;
    }

    if (!e2nodeTitle || writeupId) {
      // No title to check or editing existing writeup
      return;
    }

    // Look up the e2node by title
    const checkE2node = async () => {
      try {
        const response = await fetch(
          `/api/nodes/lookup/e2node/${encodeURIComponent(e2nodeTitle)}`,
          { credentials: 'include' }
        );
        if (response.ok) {
          const result = await response.json();
          if (result.node_id) {
            setResolvedE2nodeId(result.node_id);
            setE2nodeStatus('found');
          } else {
            setE2nodeStatus('not_found');
          }
        } else if (response.status === 404) {
          setE2nodeStatus('not_found');
        } else {
          setE2nodeStatus('not_found');
        }
      } catch (err) {
        console.error('Error checking e2node:', err);
        setE2nodeStatus('not_found');
      }
    };

    checkE2node();
  }, [e2nodeId, e2nodeTitle, writeupId])

  // Initialize Tiptap editor
  // Preprocess to convert &#91; and &#93; entities back to parseable spans for TipTap
  const editor = useEditor({
    extensions: getE2EditorExtensions(),
    content: convertEntitiesToRawBrackets(initialContent),
    editorProps: {
      attributes: {
        'aria-label': 'Writeup content',
        'role': 'textbox',
        'aria-multiline': 'true',
      },
    },
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

  // Create a new draft with retry logic for transient network failures
  const createDraft = async (content) => {
    // Convert raw bracket spans to HTML entities before saving
    const processedContent = convertRawBracketsToEntities(content);

    const maxRetries = 3;
    let lastError = null;

    for (let attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        const response = await fetchWithErrorReporting(
          '/api/drafts',
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            credentials: 'include',
            body: JSON.stringify({
              title: e2nodeTitle,
              doctext: processedContent
            })
          },
          'creating draft'
        );

        const result = await response.json();
        if (result.success) {
          setDraftId(result.draft.node_id);
          setSaveStatus('saved');
          return; // Success - exit retry loop
        } else {
          lastError = result.error || 'Unknown error';
          // Don't retry on permission/validation errors
          if (result.error === 'unauthorized' || result.error === 'invalid_title') {
            break;
          }
        }
      } catch (err) {
        lastError = err.message;
        // Network errors are worth retrying
      }

      // Wait before retry (exponential backoff: 1s, 2s, 4s)
      if (attempt < maxRetries) {
        await new Promise(resolve => setTimeout(resolve, 1000 * Math.pow(2, attempt - 1)));
      }
    }

    // All retries exhausted
    setErrorMessage(`Error creating draft: ${lastError}`);
  };

  // Save draft content with retry logic for transient network failures
  // Returns the saved doctext on success, null on failure
  const saveDraft = async (content) => {
    if (!draftId && !writeupId) return null;

    setSaveStatus('saving');

    // Convert raw bracket spans to HTML entities before saving
    // This ensures [text] in the editor saves as &#91;text&#93; in the database
    const processedContent = convertRawBracketsToEntities(content);

    const maxRetries = 3;
    let lastError = null;

    for (let attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        const endpoint = writeupId
          ? `/api/writeups/${writeupId}/action/update`
          : `/api/drafts/${draftId}`;

        const response = await fetchWithErrorReporting(
          endpoint,
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            credentials: 'include',
            body: JSON.stringify({
              doctext: processedContent
            })
          },
          'saving draft'
        );

        const result = await response.json();

        // Handle both response formats:
        // - Drafts API returns { success: true, doctext: "..." }
        // - Writeups API returns the node directly { node_id, doctext, ... }
        const isSuccess = writeupId
          ? (result.node_id !== undefined)  // Node API returns node object on success
          : result.success;                  // Drafts API uses success flag

        // Handle already_published gracefully (draft was published between edits)
        if (result.already_published) {
          setSaveStatus('saved');
          setErrorMessage(null);
          return lastSavedContentRef.current;
        }

        if (isSuccess) {
          setSaveStatus('saved');
          setErrorMessage(null);
          // Store the server-returned doctext as source of truth
          if (result.doctext !== undefined) {
            lastSavedContentRef.current = result.doctext;
            return result.doctext;
          }
          return lastSavedContentRef.current;
        } else {
          lastError = result.error || 'Unknown error';
          // Don't retry on permission/validation errors
          if (result.error === 'permission_denied' || result.error === 'not_a_draft') {
            break;
          }
        }
      } catch (err) {
        lastError = err.message;
        // Network errors are worth retrying
      }

      // Wait before retry (exponential backoff: 1s, 2s, 4s)
      if (attempt < maxRetries) {
        await new Promise(resolve => setTimeout(resolve, 1000 * Math.pow(2, attempt - 1)));
      }
    }

    // All retries exhausted
    setSaveStatus('unsaved');
    setErrorMessage(`Save error: ${lastError}`);
    return null;
  };

  // Publish draft with retry logic for transient failures
  const handlePublish = async () => {
    if (!draftId) {
      setErrorMessage('No draft to publish');
      return;
    }

    setPublishing(true);
    setErrorMessage(null);

    // Clear any pending autosave to prevent interference
    if (autosaveTimerRef.current) {
      clearTimeout(autosaveTimerRef.current);
      autosaveTimerRef.current = null;
    }

    try {
      // Save current content to draft before publishing
      const content = editorMode === 'rich' ? editor.getHTML() : htmlContent;
      const saveResult = await saveDraft(content);

      // If save failed, abort publish (saveDraft already set the error message)
      if (saveResult === null) {
        setPublishing(false);
        return;
      }

      // Validate writeuptype selection
      if (!selectedWriteuptypeId) {
        setErrorMessage('Please select a writeup type');
        setPublishing(false);
        return;
      }

      // Determine the e2node ID to use
      let targetE2nodeId = resolvedE2nodeId;

      // If no e2node exists, create one first
      if (!targetE2nodeId && e2nodeTitle) {
        try {
          const createResponse = await fetchWithErrorReporting(
            '/api/e2nodes/create',
            {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              credentials: 'include',
              body: JSON.stringify({ title: e2nodeTitle })
            },
            'creating e2node'
          );

          if (!createResponse.ok) {
            const errorText = await createResponse.text();
            setErrorMessage(`Failed to create e2node: ${createResponse.status} ${errorText || createResponse.statusText}`);
            setPublishing(false);
            return;
          }

          const createResult = await createResponse.json();
          // The nodes API returns the node directly, not wrapped in { success, e2node }
          if (createResult.node_id) {
            targetE2nodeId = createResult.node_id;
            setResolvedE2nodeId(targetE2nodeId);
            setE2nodeStatus('found');
          } else {
            setErrorMessage(`Failed to create e2node: ${createResult.error || createResult.message || 'Unknown error'}`);
            setPublishing(false);
            return;
          }
        } catch (err) {
          setErrorMessage(`Error creating e2node: ${err.message}`);
          setPublishing(false);
          return;
        }
      }

      if (!targetE2nodeId) {
        setErrorMessage('No e2node available for publishing');
        setPublishing(false);
        return;
      }

      // Publish draft with retry logic
      const maxRetries = 3;
      let lastError = null;

      for (let attempt = 1; attempt <= maxRetries; attempt++) {
        try {
          const response = await fetchWithErrorReporting(
            `/api/drafts/${draftId}/publish`,
            {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              credentials: 'include',
              body: JSON.stringify({
                parent_e2node: targetE2nodeId,
                wrtype_writeuptype: selectedWriteuptypeId,
                feedback_policy_id: 0,
                notnew: hideFromNewWriteups ? 1 : 0
              })
            },
            'publishing draft'
          );

          const result = await response.json();

          if (result.success) {
            // Clear any lingering error messages before redirect
            setErrorMessage(null);

            // Handle both fresh publish and already-published (idempotent) responses
            const writeupId = result.writeup_id;
            const e2nodeId = result.e2node_id || targetE2nodeId;

            if (result.already_published) {
              console.log('Draft was already published, redirecting...');
            }

            onPublish(writeupId);
            // Redirect to the e2node page
            window.location.href = `/title/${encodeURIComponent(e2nodeTitle)}`;
            return; // Success - exit retry loop
          } else {
            // API returned an error response
            lastError = result.error || result.message || 'Unknown error';

            // Don't retry on permission/validation errors
            if (result.error === 'permission_denied' ||
                result.error === 'not_a_draft' ||
                result.error === 'invalid_writeuptype' ||
                result.error === 'invalid_parent' ||
                result.error === 'node_locked') {
              break; // Don't retry, exit loop
            }
          }
        } catch (err) {
          lastError = err.message;
          // Network/parsing errors - worth retrying
        }

        // Wait before retry (exponential backoff: 1s, 2s, 4s)
        if (attempt < maxRetries) {
          await new Promise(resolve => setTimeout(resolve, 1000 * Math.pow(2, attempt - 1)));
        }
      }

      // All retries exhausted
      setErrorMessage(`Publish failed after ${maxRetries} attempts: ${lastError}`);
      setPublishing(false);
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
      // First apply breakTags to convert plain-text newlines to proper HTML paragraphs
      // Then convert &#91; and &#93; entities back to parseable spans for TipTap
      const withBreaks = breakTags(htmlContent);
      editor.commands.setContent(convertEntitiesToRawBrackets(withBreaks));
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

    // Create draft on first edit (new writeup only) - same logic as TipTap onUpdate
    if (!firstEditRef.current && !draftId) {
      firstEditRef.current = true;
      createDraft(newHtml);
      return; // createDraft will set draftId, subsequent edits will use saveDraft
    }

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

  // Delete draft handler
  const handleDeleteDraft = async () => {
    if (!draftId) return;

    setDeleting(true);
    setErrorMessage(null);

    try {
      const response = await fetch(`/api/drafts/${draftId}`, {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include'
      });

      const result = await response.json();

      if (result.success) {
        // Reset editor to empty state
        setDraftId(null);
        setHtmlContent('');
        if (editor) {
          editor.commands.setContent('');
        }
        setSaveStatus('saved');
        setShowDeleteConfirm(false);
        firstEditRef.current = false;
        lastSavedContentRef.current = '';
      } else {
        setErrorMessage(`Failed to delete draft: ${result.error}`);
        setShowDeleteConfirm(false);
      }
    } catch (err) {
      setErrorMessage(`Error deleting draft: ${err.message}`);
      setShowDeleteConfirm(false);
    } finally {
      setDeleting(false);
    }
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
    <div className="inline-editor">
      {/* Editor header - title and mode toggle */}
      <div className="inline-editor-header">
        {/* Title section */}
        <div>
          <h3 className="inline-editor-title">
            {writeupId
              ? (isOwnWriteup ? 'Editing your writeup' : `Editing ${writeupAuthor}'s writeup`)
              : (initialDraftId ? 'Continue your draft' : 'Add a Writeup')}
          </h3>
          {!writeupId && (
            <span className="inline-editor-subtitle">
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
        <div className="inline-editor-error">
          {errorMessage}
        </div>
      )}

      {/* Editor content */}
      {editorMode === 'rich' ? (
        <div className="inline-editor-content">
          <MenuBar editor={editor} />
          <div className="e2-editor-wrapper">
            <EditorContent editor={editor} />
          </div>
        </div>
      ) : (
        <textarea
          value={htmlContent}
          onChange={handleHtmlChange}
          onInput={(e) => {
            // Fallback for voice dictation and other input methods that may bypass onChange
            // This ensures draft creation happens even with alternative input methods
            if (e.target.value !== htmlContent) {
              handleHtmlChange(e);
            }
          }}
          placeholder="Enter HTML content here..."
          aria-label="Writeup content (HTML)"
          className="inline-editor-textarea"
          spellCheck={false}
        />
      )}

      {/* Footer with save status and actions */}
      <div className="inline-editor-footer">
        {/* First row: status and Cancel/Save buttons */}
        <div className="inline-editor-footer-row">
          <div className="inline-editor-status">
            {getSaveStatusText()}
          </div>

          <div className="inline-editor-actions">
            {/* Delete button for drafts (new writeups) */}
            {!writeupId && draftId && (
              <button
                onClick={() => setShowDeleteConfirm(true)}
                disabled={publishing || saveStatus === 'saving' || deleting}
                className="inline-editor-btn inline-editor-btn--delete"
              >
                Delete Draft
              </button>
            )}

            {/* Save button for drafts (new writeups) */}
            {!writeupId && (
              <button
                onClick={handleManualSave}
                disabled={!draftId || publishing || saveStatus === 'saving'}
                className="inline-editor-btn inline-editor-btn--save"
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

                  // Save the content and get the server-returned doctext
                  const savedContent = await saveDraft(content);

                  // Only call onSave if save was successful
                  if (savedContent !== null) {
                    onSave(savedContent);
                  }
                }}
                disabled={saveStatus === 'saving'}
                className="inline-editor-btn inline-editor-btn--primary"
              >
                {saveStatus === 'saving' ? 'Saving...' : 'Update'}
              </button>
            )}
          </div>
        </div>

        {/* Second row: Writeuptype selector, hide checkbox, and Publish button (new writeups only) */}
        {!writeupId && (
          <div className="inline-editor-publish-row">
            {/* Dynamic title preview that updates with selected writeup type */}
            <span className="inline-editor-publish-label">
              Publishing: <strong className="inline-editor-publish-title">
                {e2nodeTitle}
                {selectedWriteuptypeId && writeuptypes.length > 0 && (
                  <> ({writeuptypes.find(wt => wt.node_id === selectedWriteuptypeId)?.title || ''})</>
                )}
              </strong>
              {/* E2node status indicator */}
              {e2nodeStatus === 'checking' && (
                <span className="inline-editor-status-indicator inline-editor-status-indicator--checking">
                  (checking...)
                </span>
              )}
              {e2nodeStatus === 'found' && (
                <span className="inline-editor-status-indicator inline-editor-status-indicator--found" title="E2node exists">
                  ✓
                </span>
              )}
              {e2nodeStatus === 'not_found' && (
                <span className="inline-editor-status-indicator inline-editor-status-indicator--new" title="E2node will be created on publish">
                  (new)
                </span>
              )}
            </span>
            <span className="inline-editor-publish-label">as</span>
            <select
              value={selectedWriteuptypeId || ''}
              onChange={(e) => setSelectedWriteuptypeId(Number(e.target.value))}
              disabled={!draftId || publishing || saveStatus === 'saving'}
              className="inline-editor-select"
            >
              {writeuptypes.length > 0 ? (
                writeuptypes.map(wt => (
                  <option key={wt.node_id} value={wt.node_id}>{wt.title}</option>
                ))
              ) : (
                <option value="">Loading...</option>
              )}
            </select>
            <label className="inline-editor-checkbox-label">
              <input
                type="checkbox"
                checked={hideFromNewWriteups}
                onChange={(e) => setHideFromNewWriteups(e.target.checked)}
              />
              Hide from New Writeups
            </label>
            <button
              onClick={handlePublish}
              disabled={!draftId || !e2nodeTitle || e2nodeStatus === 'checking' || publishing || saveStatus === 'saving'}
              title={e2nodeStatus === 'not_found' ? `Will create new e2node "${e2nodeTitle}"` : ''}
              className="inline-editor-btn inline-editor-btn--primary"
            >
              {publishing ? 'Publishing...' : 'Publish'}
            </button>
          </div>
        )}
      </div>

      {/* Live Preview Section */}
      <div className="inline-editor-preview-section">
        <div className="inline-editor-preview-header">
          <h4 className="inline-editor-preview-title">
            Preview
          </h4>
          <button
            onClick={() => setShowPreview(!showPreview)}
            className="inline-editor-preview-toggle"
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

      {/* Delete confirmation modal */}
      {showDeleteConfirm && (
        <div className="inline-editor-modal-overlay">
          <div className="inline-editor-modal">
            <h3 className="inline-editor-modal-title">
              Delete Draft?
            </h3>
            <p className="inline-editor-modal-body">
              Are you sure you want to delete this draft? This action cannot be undone.
            </p>
            <div className="inline-editor-modal-actions">
              <button
                onClick={() => setShowDeleteConfirm(false)}
                disabled={deleting}
                className="inline-editor-btn inline-editor-btn--save"
              >
                Cancel
              </button>
              <button
                onClick={handleDeleteDraft}
                disabled={deleting}
                className="inline-editor-btn inline-editor-btn--delete"
              >
                {deleting ? 'Deleting...' : 'Delete'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default InlineWriteupEditor;
