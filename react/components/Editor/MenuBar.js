import React, { useState, useCallback } from 'react';
import { FaAlignLeft, FaAlignCenter, FaAlignRight } from 'react-icons/fa';

/**
 * MenuBar - Toolbar for the Tiptap editor
 *
 * Provides formatting buttons for all E2-approved HTML features.
 */
const MenuBar = ({ editor }) => {
  const [showLinkDialog, setShowLinkDialog] = useState(false);
  const [linkTitle, setLinkTitle] = useState('');
  const [linkDisplay, setLinkDisplay] = useState('');

  // Listen for Cmd+K to open link dialog
  React.useEffect(() => {
    const handleLinkDialog = () => setShowLinkDialog(true);
    window.addEventListener('e2-open-link-dialog', handleLinkDialog);
    return () => window.removeEventListener('e2-open-link-dialog', handleLinkDialog);
  }, []);

  const insertLink = useCallback(() => {
    if (linkTitle && editor) {
      editor.chain().focus().setE2Link({
        title: linkTitle,
        displayText: linkDisplay || linkTitle
      }).run();
      setLinkTitle('');
      setLinkDisplay('');
      setShowLinkDialog(false);
    }
  }, [editor, linkTitle, linkDisplay]);

  if (!editor) {
    return null;
  }

  const buttonStyle = (isActive) => ({
    padding: '4px 8px',
    margin: '2px',
    backgroundColor: isActive ? '#38495e' : '#f8f9f9',
    color: isActive ? '#fff' : '#111',
    border: '1px solid #ccc',
    borderRadius: '3px',
    cursor: 'pointer',
    fontSize: '13px',
    fontWeight: isActive ? 'bold' : 'normal',
    minWidth: '28px'
  });

  const groupStyle = {
    display: 'inline-flex',
    alignItems: 'center',
    marginRight: '10px',
    padding: '0 5px',
    borderRight: '1px solid #ddd'
  };

  return (
    <div style={{
      padding: '8px',
      backgroundColor: '#f5f5f5',
      borderBottom: '1px solid #38495e',
      borderTopLeftRadius: '4px',
      borderTopRightRadius: '4px',
      display: 'flex',
      flexWrap: 'wrap',
      alignItems: 'center'
    }}>
      {/* Text formatting */}
      <div style={groupStyle}>
        <button
          type="button"
          onClick={() => editor.chain().focus().toggleBold().run()}
          style={buttonStyle(editor.isActive('bold'))}
          title="Bold (Ctrl+B)"
        >
          <strong>B</strong>
        </button>
        <button
          type="button"
          onClick={() => editor.chain().focus().toggleItalic().run()}
          style={buttonStyle(editor.isActive('italic'))}
          title="Italic (Ctrl+I)"
        >
          <em>I</em>
        </button>
        <button
          type="button"
          onClick={() => editor.chain().focus().toggleUnderline().run()}
          style={buttonStyle(editor.isActive('underline'))}
          title="Underline (Ctrl+U)"
        >
          <u>U</u>
        </button>
        <button
          type="button"
          onClick={() => editor.chain().focus().toggleStrike().run()}
          style={buttonStyle(editor.isActive('strike'))}
          title="Strikethrough"
        >
          <s>S</s>
        </button>
        <button
          type="button"
          onClick={() => editor.chain().focus().toggleSubscript().run()}
          style={buttonStyle(editor.isActive('subscript'))}
          title="Subscript"
        >
          X<sub>2</sub>
        </button>
        <button
          type="button"
          onClick={() => editor.chain().focus().toggleSuperscript().run()}
          style={buttonStyle(editor.isActive('superscript'))}
          title="Superscript"
        >
          X<sup>2</sup>
        </button>
      </div>

      {/* Headings */}
      <div style={groupStyle}>
        <select
          onChange={(e) => {
            const level = parseInt(e.target.value, 10);
            if (level === 0) {
              editor.chain().focus().setParagraph().run();
            } else {
              editor.chain().focus().toggleHeading({ level }).run();
            }
          }}
          value={
            editor.isActive('heading', { level: 1 }) ? '1' :
            editor.isActive('heading', { level: 2 }) ? '2' :
            editor.isActive('heading', { level: 3 }) ? '3' :
            editor.isActive('heading', { level: 4 }) ? '4' :
            editor.isActive('heading', { level: 5 }) ? '5' :
            editor.isActive('heading', { level: 6 }) ? '6' : '0'
          }
          style={{
            padding: '4px 8px',
            margin: '2px',
            border: '1px solid #ccc',
            borderRadius: '3px',
            backgroundColor: '#f8f9f9',
            cursor: 'pointer',
            fontSize: '13px'
          }}
        >
          <option value="0">Paragraph</option>
          <option value="1">Heading 1</option>
          <option value="2">Heading 2</option>
          <option value="3">Heading 3</option>
          <option value="4">Heading 4</option>
          <option value="5">Heading 5</option>
          <option value="6">Heading 6</option>
        </select>
      </div>

      {/* Lists */}
      <div style={groupStyle}>
        <button
          type="button"
          onClick={() => editor.chain().focus().toggleBulletList().run()}
          style={buttonStyle(editor.isActive('bulletList'))}
          title="Bullet List"
        >
          •
        </button>
        <button
          type="button"
          onClick={() => editor.chain().focus().toggleOrderedList().run()}
          style={buttonStyle(editor.isActive('orderedList'))}
          title="Numbered List"
        >
          1.
        </button>
      </div>

      {/* Block elements */}
      <div style={groupStyle}>
        <button
          type="button"
          onClick={() => editor.chain().focus().toggleBlockquote().run()}
          style={buttonStyle(editor.isActive('blockquote'))}
          title="Blockquote"
        >
          "
        </button>
        <button
          type="button"
          onClick={() => editor.chain().focus().toggleCode().run()}
          style={buttonStyle(editor.isActive('code'))}
          title="Inline Code"
        >
          {'</>'}
        </button>
        <button
          type="button"
          onClick={() => editor.chain().focus().toggleCodeBlock().run()}
          style={buttonStyle(editor.isActive('codeBlock'))}
          title="Code Block"
        >
          {'{ }'}
        </button>
        <button
          type="button"
          onClick={() => editor.chain().focus().setHorizontalRule().run()}
          style={buttonStyle(false)}
          title="Horizontal Rule"
        >
          ─
        </button>
      </div>

      {/* Text alignment */}
      <div style={groupStyle}>
        <button
          type="button"
          onClick={() => editor.chain().focus().setTextAlign('left').run()}
          style={buttonStyle(editor.isActive({ textAlign: 'left' }))}
          title="Align Left"
        >
          <FaAlignLeft style={{ verticalAlign: 'middle' }} />
        </button>
        <button
          type="button"
          onClick={() => editor.chain().focus().setTextAlign('center').run()}
          style={buttonStyle(editor.isActive({ textAlign: 'center' }))}
          title="Align Center"
        >
          <FaAlignCenter style={{ verticalAlign: 'middle' }} />
        </button>
        <button
          type="button"
          onClick={() => editor.chain().focus().setTextAlign('right').run()}
          style={buttonStyle(editor.isActive({ textAlign: 'right' }))}
          title="Align Right"
        >
          <FaAlignRight style={{ verticalAlign: 'middle' }} />
        </button>
      </div>

      {/* E2 Link */}
      <div style={groupStyle}>
        <button
          type="button"
          onClick={() => {
            // Get selected text to pre-fill dialog
            const { from, to } = editor.state.selection;
            const selectedText = editor.state.doc.textBetween(from, to, '');
            setLinkTitle(selectedText);
            setLinkDisplay(selectedText);
            setShowLinkDialog(true);
          }}
          style={buttonStyle(editor.isActive('e2link'))}
          title="Insert E2 Link (Ctrl+K)"
        >
          [link]
        </button>
      </div>

      {/* Raw Brackets */}
      <div style={groupStyle}>
        <button
          type="button"
          onClick={() => editor.chain().focus().insertRawLeftBracket().run()}
          style={buttonStyle(false)}
          title="Insert Raw Left Bracket (won't be parsed as link)"
        >
          &#91;
        </button>
        <button
          type="button"
          onClick={() => editor.chain().focus().insertRawRightBracket().run()}
          style={buttonStyle(false)}
          title="Insert Raw Right Bracket (won't be parsed as link)"
        >
          &#93;
        </button>
      </div>

      {/* Table */}
      <div style={groupStyle}>
        <button
          type="button"
          onClick={() => editor.chain().focus().insertTable({ rows: 3, cols: 3 }).run()}
          style={buttonStyle(false)}
          title="Insert Table"
        >
          ⊞
        </button>
        {editor.isActive('table') && (
          <>
            <button
              type="button"
              onClick={() => editor.chain().focus().addColumnAfter().run()}
              style={buttonStyle(false)}
              title="Add Column"
            >
              +Col
            </button>
            <button
              type="button"
              onClick={() => editor.chain().focus().addRowAfter().run()}
              style={buttonStyle(false)}
              title="Add Row"
            >
              +Row
            </button>
            <button
              type="button"
              onClick={() => editor.chain().focus().deleteTable().run()}
              style={buttonStyle(false)}
              title="Delete Table"
            >
              ×
            </button>
          </>
        )}
      </div>

      {/* Undo/Redo */}
      <div style={{ ...groupStyle, borderRight: 'none' }}>
        <button
          type="button"
          onClick={() => editor.chain().focus().undo().run()}
          disabled={!editor.can().undo()}
          style={{
            ...buttonStyle(false),
            opacity: editor.can().undo() ? 1 : 0.5
          }}
          title="Undo (Ctrl+Z)"
        >
          ↩
        </button>
        <button
          type="button"
          onClick={() => editor.chain().focus().redo().run()}
          disabled={!editor.can().redo()}
          style={{
            ...buttonStyle(false),
            opacity: editor.can().redo() ? 1 : 0.5
          }}
          title="Redo (Ctrl+Y)"
        >
          ↪
        </button>
      </div>

      {/* Link dialog modal */}
      {showLinkDialog && (
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
            padding: '20px',
            borderRadius: '8px',
            minWidth: '350px',
            boxShadow: '0 4px 20px rgba(0,0,0,0.3)'
          }}>
            <h3 style={{ marginTop: 0, marginBottom: '15px', color: '#38495e' }}>
              Insert E2 Link
            </h3>
            <div style={{ marginBottom: '12px' }}>
              <label style={{ display: 'block', marginBottom: '4px', fontWeight: 'bold' }}>
                Node Title:
              </label>
              <input
                type="text"
                value={linkTitle}
                onChange={(e) => setLinkTitle(e.target.value)}
                placeholder="e.g., Everything2"
                style={{
                  width: '100%',
                  padding: '8px',
                  border: '1px solid #ccc',
                  borderRadius: '4px',
                  fontSize: '14px',
                  boxSizing: 'border-box'
                }}
                autoFocus
              />
            </div>
            <div style={{ marginBottom: '15px' }}>
              <label style={{ display: 'block', marginBottom: '4px', fontWeight: 'bold' }}>
                Display Text (optional):
              </label>
              <input
                type="text"
                value={linkDisplay}
                onChange={(e) => setLinkDisplay(e.target.value)}
                placeholder="Leave blank to use node title"
                style={{
                  width: '100%',
                  padding: '8px',
                  border: '1px solid #ccc',
                  borderRadius: '4px',
                  fontSize: '14px',
                  boxSizing: 'border-box'
                }}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') {
                    insertLink();
                  }
                }}
              />
            </div>
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px' }}>
              <button
                type="button"
                onClick={() => {
                  setShowLinkDialog(false);
                  setLinkTitle('');
                  setLinkDisplay('');
                }}
                style={{
                  padding: '8px 16px',
                  backgroundColor: '#f5f5f5',
                  border: '1px solid #ccc',
                  borderRadius: '4px',
                  cursor: 'pointer'
                }}
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={insertLink}
                disabled={!linkTitle}
                style={{
                  padding: '8px 16px',
                  backgroundColor: linkTitle ? '#4060b0' : '#ccc',
                  color: '#fff',
                  border: 'none',
                  borderRadius: '4px',
                  cursor: linkTitle ? 'pointer' : 'not-allowed'
                }}
              >
                Insert Link
              </button>
            </div>
            <div style={{ marginTop: '15px', fontSize: '12px', color: '#666' }}>
              <strong>Result:</strong> {linkTitle ? (
                linkDisplay && linkDisplay !== linkTitle
                  ? `[${linkTitle}|${linkDisplay}]`
                  : `[${linkTitle}]`
              ) : '(enter node title)'}
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default MenuBar;
