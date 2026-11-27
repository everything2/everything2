import React from 'react'
import { render, screen, fireEvent } from '@testing-library/react'

// TipTap v3's useEditor can hand a component an editor it has already destroyed (#4639). Loading
// content into it must not throw: an uncaught throw in an effect unmounts the whole page, and one
// in a handler breaks the action. The writeup editors load content through setEditorContent.
const destroyedEditor = {
  isDestroyed: true,
  get commands() { throw new TypeError("Cannot read properties of null (reading 'commands')") },
  getHTML() { throw new TypeError('destroyed') },
  on() {}, off() {},
}

jest.mock('@tiptap/react', () => ({
  ...jest.requireActual('@tiptap/react'),
  useEditor: () => destroyedEditor,
  EditorContent: () => null,
}))
jest.mock('./MenuBar', () => () => null)

import EditorBeta from '../Documents/EditorBeta'
import InlineWriteupEditor from '../InlineWriteupEditor'

beforeEach(() => {
  global.fetch = jest.fn(() => Promise.resolve({ ok: true, json: () => Promise.resolve({ success: true }) }))
  window.localStorage.clear()
})

describe('writeup editors with a destroyed TipTap instance', () => {
  const data = {
    canAccess: true,
    approvedTags: ['p'],
    drafts: [{ node_id: 5, title: 'My draft', doctext: '<p>draft text</p>', status: 'private' }],
    statuses: [{ id: '1', name: 'private' }],
  }

  it('E2 Editor Beta loads a draft and starts a new one', () => {
    render(<EditorBeta data={data} user={{ title: 'tester' }} />)
    fireEvent.click(document.querySelector('.editor-beta-draft-card-body'))
    expect(screen.getByDisplayValue('My draft')).toBeInTheDocument()
    fireEvent.click(screen.getByText(/New Draft/))
    expect(screen.queryByDisplayValue('My draft')).not.toBeInTheDocument()
  })

  it('the inline writeup editor switches from HTML to rich mode', () => {
    window.localStorage.setItem('e2_editor_mode', 'html')
    render(<InlineWriteupEditor e2nodeId={1} e2nodeTitle="A node" initialContent="<p>text</p>" />)
    const toggle = document.querySelector('.e2-mode-toggle')
    expect(toggle).toBeInTheDocument()
    expect(() => fireEvent.click(toggle)).not.toThrow()
    expect(document.querySelector('.e2-mode-toggle-option.active').textContent).toMatch(/Rich/)
  })
})
