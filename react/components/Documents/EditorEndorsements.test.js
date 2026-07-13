import React from 'react'
import { render, waitFor, fireEvent } from '@testing-library/react'
import EditorEndorsements from './EditorEndorsements'

// Fully client-resolved (#4528): the Page is a pure gate. EditorEndorsements reads the selected
// `editor` id off the URL and fetches GET /api/editor_endorsements (public), which lists the editors
// and, for a selected editor, the nodes they've C!'d. Selecting an editor refetches IN PLACE (no
// reload), syncing the URL via history.pushState.

const setSearch = (search) => { window.location.search = search }
const setLocation = (href) => {
  const u = new URL(href)
  window.location.href = href
  window.location.pathname = u.pathname
  window.location.search = u.search
}
const mockFetch = (payload) => jest.fn(() => Promise.resolve({ json: () => Promise.resolve(payload) }))

beforeEach(() => setLocation('http://localhost/title/Editor+Endorsements'))
afterEach(() => { delete global.fetch; jest.restoreAllMocks() })

describe('EditorEndorsements — fetch (#4528)', () => {
  it('fetches the endpoint and renders the editor picker', async () => {
    global.fetch = mockFetch({
      success: 1, editors: [{ node_id: 113, title: 'root' }, { node_id: 99, title: 'someeditor' }],
      selected_editor: null, endorsements: [],
    })
    const { container } = render(<EditorEndorsements />)
    await waitFor(() => expect(container.querySelector('.editor-endorsements__select')).toBeTruthy())
    expect(global.fetch.mock.calls[0][0]).toMatch(/^\/api\/editor_endorsements\?/)
    expect(container.querySelectorAll('.editor-endorsements__select option')).toHaveLength(3) // placeholder + 2
  })

  it('passes the ?editor id through to the endpoint and renders endorsements', async () => {
    setSearch('?editor=113')
    global.fetch = mockFetch({
      success: 1, editors: [{ node_id: 113, title: 'root' }],
      selected_editor: { node_id: 113, title: 'root' },
      endorsements: [
        { node_id: 42, title: 'Cool Writeup', type: 'e2node', writeup_count: 3 },
        { node_id: 43, title: 'A Document', type: 'document' },
      ],
    })
    const { container } = render(<EditorEndorsements />)
    await waitFor(() => expect(container.querySelector('.editor-endorsements__results')).toBeTruthy())
    expect(global.fetch.mock.calls[0][0]).toBe('/api/editor_endorsements?editor=113')
    expect(container.textContent).toMatch(/has endorsed 2 nodes/)
    expect(container.textContent).toMatch(/Cool Writeup/)
    expect(container.textContent).toMatch(/3 writeups/)
    expect(container.textContent).toMatch(/\(document\)/)
  })

  it('strips non-digits from a garbage ?editor before fetching (injection-safe)', async () => {
    setSearch('?editor=113;DROP')
    global.fetch = mockFetch({ success: 1, editors: [], selected_editor: null, endorsements: [] })
    render(<EditorEndorsements />)
    await waitFor(() => expect(global.fetch).toHaveBeenCalled())
    expect(global.fetch.mock.calls[0][0]).toBe('/api/editor_endorsements?editor=113')
  })

  it('shows the empty copy when a selected editor has no endorsements', async () => {
    setSearch('?editor=113')
    global.fetch = mockFetch({
      success: 1, editors: [{ node_id: 113, title: 'root' }],
      selected_editor: { node_id: 113, title: 'root' }, endorsements: [],
    })
    const { container } = render(<EditorEndorsements />)
    await waitFor(() => expect(container.textContent).toMatch(/No endorsements found/i))
  })

  it('picks an editor in place: refetches with ?editor and pushes URL, no reload', async () => {
    const pushSpy = jest.spyOn(window.history, 'pushState').mockImplementation(() => {})
    global.fetch = mockFetch({
      success: 1, editors: [{ node_id: 113, title: 'root' }, { node_id: 99, title: 'someeditor' }],
      selected_editor: null, endorsements: [],
    })
    const { container } = render(<EditorEndorsements />)
    await waitFor(() => expect(container.querySelector('.editor-endorsements__select')).toBeTruthy())

    fireEvent.change(container.querySelector('.editor-endorsements__select'), { target: { value: '99' } })
    fireEvent.submit(container.querySelector('.editor-endorsements__form'))
    await waitFor(() => expect(global.fetch.mock.calls.length).toBe(2))

    expect(window.location.href).toBe('http://localhost/title/Editor+Endorsements') // no hard navigation
    expect(global.fetch.mock.calls[1][0]).toBe('/api/editor_endorsements?editor=99')
    expect(pushSpy.mock.calls[pushSpy.mock.calls.length - 1][2]).toContain('editor=99')
  })
})
