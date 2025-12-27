import React, { useMemo } from 'react';
import { convertToE2Syntax } from './E2LinkExtension';
import { convertRawBracketsToEntities } from './RawBracketExtension';
import { renderE2Content } from './E2HtmlSanitizer';

/**
 * PreviewContent - Renders live preview of editor content
 *
 * Shared component used by both EditorBeta and InlineWriteupEditor.
 * Updates reactively via previewTrigger when editor content changes.
 *
 * Props:
 * - editor: TipTap editor instance
 * - editorMode: 'rich' or 'html'
 * - htmlContent: Raw HTML content (used when editorMode is 'html')
 * - previewTrigger: Counter that forces re-computation when content changes
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

export default PreviewContent;
