import React, { useState, useCallback, useEffect, useRef } from 'react';
import { FaAlignLeft, FaAlignCenter, FaAlignRight } from 'react-icons/fa';

/**
 * LiteralCharDropdown - menu for inserting characters that the parser would
 * otherwise eat: [, ] (E2 link syntax) and <, > (HTML-tag-shaped, stripped by
 * the sanitizer). Each item invokes the corresponding insertRaw* command on
 * the editor; they serialize to &#91;/&#93;/&#60;/&#62; entities via
 * convertRawBracketsToEntities and survive the sanitizer's placeholder pass.
 */
const LITERAL_CHARS = [
  { label: '[',  command: 'insertRawLeftBracket',  title: 'Insert literal [ (won’t be parsed as E2 link)' },
  { label: ']',  command: 'insertRawRightBracket', title: 'Insert literal ] (won’t be parsed as E2 link)' },
  { label: '<',  command: 'insertRawLessThan',    title: 'Insert literal < (won’t be stripped as HTML tag)' },
  { label: '>',  command: 'insertRawGreaterThan', title: 'Insert literal > (won’t be stripped as HTML tag)' },
];

const LiteralCharDropdown = ({ editor }) => {
  const [open, setOpen] = useState(false);
  const wrapperRef = useRef(null);

  useEffect(() => {
    if (!open) return;
    const onDocClick = (e) => {
      if (wrapperRef.current && !wrapperRef.current.contains(e.target)) {
        setOpen(false);
      }
    };
    const onKeyDown = (e) => { if (e.key === 'Escape') setOpen(false); };
    document.addEventListener('mousedown', onDocClick);
    document.addEventListener('keydown', onKeyDown);
    return () => {
      document.removeEventListener('mousedown', onDocClick);
      document.removeEventListener('keydown', onKeyDown);
    };
  }, [open]);

  const insert = (commandName) => {
    if (!editor) return;
    const chain = editor.chain().focus();
    if (typeof chain[commandName] === 'function') {
      chain[commandName]().run();
    }
    setOpen(false);
  };

  return (
    <div className="editor-menubar__dropdown" ref={wrapperRef}>
      <button
        type="button"
        onClick={() => setOpen(o => !o)}
        className="editor-menubar__btn"
        title="Insert literal punctuation"
        aria-haspopup="menu"
        aria-expanded={open}
      >
        {'[<…>]'}
      </button>
      {open && (
        <div className="editor-menubar__dropdown-menu" role="menu">
          {LITERAL_CHARS.map(item => (
            <button
              key={item.command}
              type="button"
              role="menuitem"
              onClick={() => insert(item.command)}
              className="editor-menubar__dropdown-item"
              title={item.title}
            >
              {item.label}
            </button>
          ))}
        </div>
      )}
    </div>
  );
};

/**
 * MenuBar - Toolbar for the Tiptap editor
 *
 * Provides formatting buttons for all E2-approved HTML features.
 * Styles are in CSS classes (editor-menubar__*)
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

  // Helper to get button class based on active state
  const btnClass = (isActive, isDisabled = false) => {
    let cls = 'editor-menubar__btn';
    if (isActive) cls += ' editor-menubar__btn--active';
    if (isDisabled) cls += ' editor-menubar__btn--disabled';
    return cls;
  };

  return (
    <div className="editor-menubar">
      {/* Text formatting */}
      <div className="editor-menubar__group">
        <button
          type="button"
          onClick={() => editor.chain().focus().toggleBold().run()}
          className={btnClass(editor.isActive('bold'))}
          title="Bold (Ctrl+B)"
        >
          <strong>B</strong>
        </button>
        <button
          type="button"
          onClick={() => editor.chain().focus().toggleItalic().run()}
          className={btnClass(editor.isActive('italic'))}
          title="Italic (Ctrl+I)"
        >
          <em>I</em>
        </button>
        <button
          type="button"
          onClick={() => editor.chain().focus().toggleUnderline().run()}
          className={btnClass(editor.isActive('underline'))}
          title="Underline (Ctrl+U)"
        >
          <u>U</u>
        </button>
        <button
          type="button"
          onClick={() => editor.chain().focus().toggleStrike().run()}
          className={btnClass(editor.isActive('strike'))}
          title="Strikethrough"
        >
          <s>S</s>
        </button>
        <button
          type="button"
          onClick={() => editor.chain().focus().toggleSubscript().run()}
          className={btnClass(editor.isActive('subscript'))}
          title="Subscript"
        >
          X<sub>2</sub>
        </button>
        <button
          type="button"
          onClick={() => editor.chain().focus().toggleSuperscript().run()}
          className={btnClass(editor.isActive('superscript'))}
          title="Superscript"
        >
          X<sup>2</sup>
        </button>
      </div>

      {/* Headings */}
      <div className="editor-menubar__group">
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
          className="editor-menubar__select"
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
      <div className="editor-menubar__group">
        <button
          type="button"
          onClick={() => editor.chain().focus().toggleBulletList().run()}
          className={btnClass(editor.isActive('bulletList'))}
          title="Bullet List"
        >
          •
        </button>
        <button
          type="button"
          onClick={() => editor.chain().focus().toggleOrderedList().run()}
          className={btnClass(editor.isActive('orderedList'))}
          title="Numbered List"
        >
          1.
        </button>
      </div>

      {/* Block elements */}
      <div className="editor-menubar__group">
        <button
          type="button"
          onClick={() => editor.chain().focus().toggleBlockquote().run()}
          className={btnClass(editor.isActive('blockquote'))}
          title="Blockquote"
        >
          "
        </button>
        <button
          type="button"
          onClick={() => editor.chain().focus().toggleCode().run()}
          className={btnClass(editor.isActive('code'))}
          title="Inline Code"
        >
          {'</>'}
        </button>
        <button
          type="button"
          onClick={() => editor.chain().focus().toggleCodeBlock().run()}
          className={btnClass(editor.isActive('codeBlock'))}
          title="Code Block"
        >
          {'{ }'}
        </button>
        <button
          type="button"
          onClick={() => editor.chain().focus().setHorizontalRule().run()}
          className={btnClass(false)}
          title="Horizontal Rule"
        >
          ─
        </button>
      </div>

      {/* Text alignment */}
      <div className="editor-menubar__group">
        <button
          type="button"
          onClick={() => editor.chain().focus().setTextAlign('left').run()}
          className={btnClass(editor.isActive({ textAlign: 'left' }))}
          title="Align Left"
        >
          <FaAlignLeft className="editor-menubar__icon" />
        </button>
        <button
          type="button"
          onClick={() => editor.chain().focus().setTextAlign('center').run()}
          className={btnClass(editor.isActive({ textAlign: 'center' }))}
          title="Align Center"
        >
          <FaAlignCenter className="editor-menubar__icon" />
        </button>
        <button
          type="button"
          onClick={() => editor.chain().focus().setTextAlign('right').run()}
          className={btnClass(editor.isActive({ textAlign: 'right' }))}
          title="Align Right"
        >
          <FaAlignRight className="editor-menubar__icon" />
        </button>
      </div>

      {/* E2 Link */}
      <div className="editor-menubar__group">
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
          className={btnClass(editor.isActive('e2link'))}
          title="Insert E2 Link (Ctrl+K)"
        >
          [link]
        </button>
      </div>

      {/* Literal punctuation (chars the parser would otherwise eat) */}
      <div className="editor-menubar__group">
        <LiteralCharDropdown editor={editor} />
      </div>

      {/* Table */}
      <div className="editor-menubar__group">
        <button
          type="button"
          onClick={() => editor.chain().focus().insertTable({ rows: 3, cols: 3 }).run()}
          className={btnClass(false)}
          title="Insert Table"
        >
          ⊞
        </button>
        {editor.isActive('table') && (
          <>
            <button
              type="button"
              onClick={() => editor.chain().focus().addColumnAfter().run()}
              className={btnClass(false)}
              title="Add Column"
            >
              +Col
            </button>
            <button
              type="button"
              onClick={() => editor.chain().focus().addRowAfter().run()}
              className={btnClass(false)}
              title="Add Row"
            >
              +Row
            </button>
            <button
              type="button"
              onClick={() => editor.chain().focus().deleteTable().run()}
              className={btnClass(false)}
              title="Delete Table"
            >
              ×
            </button>
          </>
        )}
      </div>

      {/* Undo/Redo */}
      <div className="editor-menubar__group editor-menubar__group--no-border">
        <button
          type="button"
          onClick={() => editor.chain().focus().undo().run()}
          disabled={!editor.can().undo()}
          className={btnClass(false, !editor.can().undo())}
          title="Undo (Ctrl+Z)"
        >
          ↩
        </button>
        <button
          type="button"
          onClick={() => editor.chain().focus().redo().run()}
          disabled={!editor.can().redo()}
          className={btnClass(false, !editor.can().redo())}
          title="Redo (Ctrl+Y)"
        >
          ↪
        </button>
      </div>

      {/* Link dialog modal */}
      {showLinkDialog && (
        <div className="editor-menubar__modal-overlay">
          <div className="editor-menubar__modal">
            <h3 className="editor-menubar__modal-title">
              Insert E2 Link
            </h3>
            <div className="editor-menubar__form-group">
              <label className="editor-menubar__label">
                Node Title:
              </label>
              <input
                type="text"
                value={linkTitle}
                onChange={(e) => setLinkTitle(e.target.value)}
                placeholder="e.g., Everything2"
                className="editor-menubar__input"
                autoFocus
              />
            </div>
            <div className="editor-menubar__form-group editor-menubar__form-group--last">
              <label className="editor-menubar__label">
                Display Text (optional):
              </label>
              <input
                type="text"
                value={linkDisplay}
                onChange={(e) => setLinkDisplay(e.target.value)}
                placeholder="Leave blank to use node title"
                className="editor-menubar__input"
                onKeyDown={(e) => {
                  if (e.key === 'Enter') {
                    insertLink();
                  }
                }}
              />
            </div>
            <div className="editor-menubar__actions">
              <button
                type="button"
                onClick={() => {
                  setShowLinkDialog(false);
                  setLinkTitle('');
                  setLinkDisplay('');
                }}
                className="editor-menubar__btn-cancel"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={insertLink}
                disabled={!linkTitle}
                className={`editor-menubar__btn-submit${!linkTitle ? ' editor-menubar__btn-submit--disabled' : ''}`}
              >
                Insert Link
              </button>
            </div>
            <div className="editor-menubar__preview">
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
