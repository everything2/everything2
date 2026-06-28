import React from 'react'
import { render, fireEvent, waitFor } from '@testing-library/react'
import CreateCategory from './CreateCategory'
import fixture from '../../__fixtures__/pagestate/create_category.json'

// Mock Tiptap editor - the real editor requires a DOM environment.
jest.mock('@tiptap/react', () => ({
  useEditor: jest.fn(() => ({
    commands: { setContent: jest.fn() },
    getHTML: jest.fn(() => '<p>Category description</p>'),
  })),
  EditorContent: () => <div data-testid="editor-content">Mock Editor Content</div>,
}))

jest.mock('../Editor/MenuBar', () => () => <div data-testid="menu-bar">Mock Menu Bar</div>)
jest.mock('../Editor/PreviewContent', () => () => <div data-testid="preview">Mock Preview</div>)
jest.mock('../Editor/EditorModeToggle', () => () => <div data-testid="mode-toggle">Mock Toggle</div>)
jest.mock('../Editor/E2LinkExtension', () => ({
  E2Link: {},
  convertToE2Syntax: jest.fn((html) => html),
}))
jest.mock('../Editor/RawBracketExtension', () => ({
  RawBracket: {},
  convertRawBracketsToEntities: jest.fn((html) => html),
  convertEntitiesToRawBrackets: jest.fn((html) => html),
}))
jest.mock('../Editor/E2HtmlSanitizer', () => ({
  normalizeEditorHtml: jest.fn((html) => html),
}))
jest.mock('../Editor/useE2Editor', () => ({
  getE2EditorExtensions: jest.fn(() => []),
}))
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('CreateCategory (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<CreateCategory data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<CreateCategory data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// Migration from op=new to POST /api/category/create (#4340) -- the category
// endpoint applies the chosen maintainer + description at create time.
describe('create-node API migration', () => {
  let originalLocation

  // Minimal props that render the create form (no mustLogin/forbidden/error).
  const formProps = {
    guest_user_id: 1,
    category_type_id: 1522375,
    usergroups: [],
  }

  // Viewer identity now comes from the global user prop (#4399).
  const formUser = { node_id: 123, title: 'testuser', level: 5 }

  beforeEach(() => {
    originalLocation = window.location
    delete window.location
    window.location = { href: '' }
    global.fetch = jest.fn(() =>
      Promise.resolve({ ok: true, json: async () => ({ success: 1, node_id: 999 }) })
    )
  })

  afterEach(() => {
    window.location = originalLocation
    jest.restoreAllMocks()
  })

  it('creates a category via /api/category/create with title+maintainer+doctext and redirects', async () => {
    const { container } = render(<CreateCategory data={formProps} user={formUser} />)

    const input = container.querySelector('.create-category__text-input')
    fireEvent.change(input, { target: { value: 'My Category' } })

    fireEvent.submit(input.closest('form'))

    await waitFor(() => expect(global.fetch).toHaveBeenCalled())
    const call = global.fetch.mock.calls[0]
    expect(call[0]).toBe('/api/category/create')
    const body = JSON.parse(call[1].body)
    expect(body.title).toBe('My Category')
    // maintainer defaults to "Me" (user.node_id); doctext is the editor content
    expect(body.maintainer).toBe(formUser.node_id)
    expect(typeof body.doctext).toBe('string')

    await waitFor(() => expect(window.location.href).toBe('/node/999'))
  })

  it('does not call the API when the category name is empty', () => {
    window.alert = jest.fn()
    const { container } = render(<CreateCategory data={formProps} user={formUser} />)
    fireEvent.submit(container.querySelector('form'))
    expect(global.fetch).not.toHaveBeenCalled()
  })

  it('reads viewer identity from the user prop, not contentData (#4399)', () => {
    const { container } = render(
      <CreateCategory data={formProps} user={{ node_id: 123, title: 'alice', level: 5 }} />
    )
    // Example list + maintainer "Me (...)" option render the viewer's title.
    expect(container.textContent).toContain("alice's Favorite Movies")
    expect(container.textContent).toContain('Me (alice)')
    // The "Me" maintainer option carries the viewer's node_id as its value.
    const meOption = Array.from(container.querySelectorAll('option')).find(
      (o) => o.textContent === 'Me (alice)'
    )
    expect(meOption.value).toBe('123')
  })
})
