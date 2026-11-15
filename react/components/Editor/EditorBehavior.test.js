import React from 'react'
import fs from 'fs'
import path from 'path'
import { render, screen, act } from '@testing-library/react'
import { useEditor, EditorContent } from '@tiptap/react'
import { getE2EditorExtensions } from './useE2Editor'
import { Editor } from '@tiptap/core'
import MenuBar from './MenuBar'
import PreviewContent from './PreviewContent'
import { convertToE2Syntax } from './E2LinkExtension'
import { convertRawBracketsToEntities } from './RawBracketExtension'

// Editor behaviour the E2 editors depend on, exercised with the real schema (#4598).
// The other component tests mock getE2EditorExtensions() away, so nothing caught
// regressions in the toolbar's live state or in update events during a TipTap upgrade.

let editorRef = null

const Harness = ({ content = '<p>hello world</p>', onUpdate }) => {
  const editor = useEditor({ extensions: getE2EditorExtensions(), content, onUpdate })
  editorRef = editor
  return (
    <div>
      <MenuBar editor={editor} />
      <EditorContent editor={editor} />
    </div>
  )
}

const button = (title) => screen.getByTitle(title)
const isActive = (title) => button(title).className.includes('editor-menubar__btn--active')

afterEach(() => {
  if (editorRef && !editorRef.isDestroyed) editorRef.destroy()
  editorRef = null
})

describe('MenuBar tracks editor state', () => {
  it('reflects mark changes made through the editor', () => {
    render(<Harness />)
    expect(isActive('Bold (Ctrl+B)')).toBe(false)

    act(() => { editorRef.chain().selectAll().toggleBold().run() })
    expect(isActive('Bold (Ctrl+B)')).toBe(true)

    act(() => { editorRef.chain().selectAll().toggleBold().run() })
    expect(isActive('Bold (Ctrl+B)')).toBe(false)
  })

  it('reflects selection moving into differently formatted text', () => {
    render(<Harness content="<p><em>italic</em> plain</p>" />)

    act(() => { editorRef.commands.setTextSelection(3) })
    expect(isActive('Italic (Ctrl+I)')).toBe(true)

    act(() => { editorRef.commands.setTextSelection(10) })
    expect(isActive('Italic (Ctrl+I)')).toBe(false)
  })

  it('enables undo after an edit and redo after an undo', () => {
    render(<Harness />)
    expect(button('Undo (Ctrl+Z)')).toBeDisabled()

    act(() => { editorRef.commands.insertContent(' more') })
    expect(button('Undo (Ctrl+Z)')).not.toBeDisabled()
    expect(button('Redo (Ctrl+Y)')).toBeDisabled()

    act(() => { editorRef.commands.undo() })
    expect(button('Redo (Ctrl+Y)')).not.toBeDisabled()
  })

  it('shows the table controls only while the cursor is in a table', () => {
    render(<Harness content="<p>before</p><table><tr><td>cell</td></tr></table>" />)
    expect(screen.queryByTitle(/delete table/i)).toBeNull()

    act(() => { editorRef.commands.setTextSelection(10) })
    expect(screen.getByTitle(/delete table/i)).toBeInTheDocument()
  })
})

describe('E2 editor commands (real schema)', () => {
  const saved = () => convertRawBracketsToEntities(convertToE2Syntax(editorRef.getHTML()))

  it('inserts an E2 link as bracket syntax', () => {
    render(<Harness content="<p>see it</p>" />)
    act(() => { editorRef.chain().setTextSelection(5).setE2Link({ title: 'Some Node', displayText: 'this' }).run() })
    expect(saved()).toBe('<p>see [Some Node|this]it</p>')
  })

  it('wraps the selected text in an E2 link', () => {
    render(<Harness content="<p>hello world</p>" />)
    act(() => { editorRef.chain().setTextSelection({ from: 7, to: 12 }).toggleE2Link({}).run() })
    expect(saved()).toBe('<p>hello [world]</p>')
  })

  it('inserts literal brackets and angle brackets at the start of text', () => {
    render(<Harness content="<p>text</p>" />)
    act(() => {
      editorRef.chain().setTextSelection(1).insertRawLeftBracket().insertRawLessThan().run()
      editorRef.chain().focus('end').insertRawGreaterThan().insertRawRightBracket().run()
    })
    expect(saved()).toBe('<p>&#91;&#60;text&#62;&#93;</p>')
  })

  it('aligns a paragraph with the align attribute', () => {
    render(<Harness content="<p>text</p>" />)
    act(() => { editorRef.chain().setTextSelection(2).setTextAlign('center').run() })
    expect(saved()).toBe('<p align="center">text</p>')
    expect(isActive('Align Center')).toBe(true)

    act(() => { editorRef.chain().setTextSelection(2).unsetTextAlign().run() })
    expect(saved()).toBe('<p>text</p>')
  })

  it('aligns a heading with the align attribute', () => {
    render(<Harness content="<h2>title</h2>" />)
    act(() => { editorRef.chain().setTextSelection(2).setTextAlign('right').run() })
    expect(saved()).toBe('<h2 align="right">title</h2>')
  })
})

describe('update events', () => {
  it('does not fire onUpdate for the initial content', () => {
    const onUpdate = jest.fn()
    render(<Harness onUpdate={onUpdate} />)
    expect(onUpdate).not.toHaveBeenCalled()
  })

  it('does not fire onUpdate for a content load with emitUpdate: false', () => {
    const onUpdate = jest.fn()
    render(<Harness onUpdate={onUpdate} />)
    act(() => { editorRef.commands.setContent('<p>loaded</p>', { emitUpdate: false }) })
    expect(onUpdate).not.toHaveBeenCalled()
    expect(editorRef.getHTML()).toBe('<p>loaded</p>')
  })

  it('fires onUpdate for user edits', () => {
    const onUpdate = jest.fn()
    render(<Harness onUpdate={onUpdate} />)
    act(() => { editorRef.commands.insertContent(' typed') })
    expect(onUpdate).toHaveBeenCalled()
  })
})

// Programmatic content loads (initial load, Rich <-> HTML mode switches, resets after save)
// must not fire onUpdate: the editors treat onUpdate as "the user changed something" and use
// it to mark content unsaved, create drafts and schedule autosaves. TipTap v3 changed
// setContent() to emit an update by default, so every call has to opt out explicitly.
describe('programmatic setContent calls opt out of update events', () => {
  const root = path.resolve(__dirname, '..')
  const sourceFiles = (dir) => fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const full = path.join(dir, entry.name)
    if (entry.isDirectory()) return sourceFiles(full)
    return /\.js$/.test(entry.name) && !/\.test\.js$/.test(entry.name) ? [full] : []
  })

  const calls = sourceFiles(root).flatMap((file) => {
    const src = fs.readFileSync(file, 'utf8')
    const found = []
    const re = /\.commands\.(setContent|clearContent)\(/g
    let m
    while ((m = re.exec(src))) {
      // Capture the argument list by matching parentheses from the opening one.
      let depth = 0
      let i = m.index + m[0].length - 1
      const start = i
      for (; i < src.length; i++) {
        if (src[i] === '(') depth++
        else if (src[i] === ')' && --depth === 0) break
      }
      const line = src.slice(0, m.index).split('\n').length
      found.push({ where: `${path.relative(root, file)}:${line}`, args: src.slice(start + 1, i) })
    }
    return found
  })

  it('finds the editor content loads (guards against scanning nothing)', () => {
    expect(calls.length).toBeGreaterThan(10)
  })

  it('passes { emitUpdate: false } on every call', () => {
    const missing = calls.filter(({ args }) => !/emitUpdate:\s*false/.test(args)).map(({ where }) => where)
    expect(missing).toEqual([])
  })
})

// useEditor() can briefly hand a render an editor it has already destroyed (seen on page load,
// when the page tree mounts more than once). TipTap v3's destroy() nulls the schema and command
// manager, so getHTML()/can() on it throw. Rendering against one must not throw.
describe('rendering against a destroyed editor', () => {
  const destroyedEditor = () => {
    const editor = new Editor({ extensions: getE2EditorExtensions(), content: '<p>gone</p>' })
    editor.destroy()
    return editor
  }

  it('PreviewContent renders nothing instead of throwing', () => {
    expect(() => render(<PreviewContent editor={destroyedEditor()} editorMode="rich" htmlContent="" previewTrigger={0} />)).not.toThrow()
  })

  it('MenuBar renders nothing instead of throwing', () => {
    const { container } = render(<MenuBar editor={destroyedEditor()} />)
    expect(container.querySelector('.editor-menubar')).toBeNull()
  })
})
