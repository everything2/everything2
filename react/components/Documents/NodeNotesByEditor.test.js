import React from 'react'
import { render, waitFor, fireEvent } from '@testing-library/react'
import NodeNotesByEditor from './NodeNotesByEditor'

// Fully client-resolved (#4528): the Page is a pure gate. NodeNotesByEditor reads
// targetUser/gotime/start/limit off the URL and fetches GET /api/node_notes_by_editor (admin-gated).
// The error copy (admin / user_not_found) is owned by the component, keyed on the `state` flag.
// Search + pagination refetch IN PLACE (no reload), syncing the URL via history.pushState.

const setSearch = (search) => { window.location.search = search }
const setLocation = (href) => {
  const u = new URL(href)
  window.location.href = href
  window.location.pathname = u.pathname
  window.location.search = u.search
}
const mockFetch = (payload) => jest.fn(() => Promise.resolve({ json: () => Promise.resolve(payload) }))

beforeEach(() => { setLocation('http://localhost/?node_id=2117964'); window.e2 = { node_id: 2117964 } })
afterEach(() => { delete global.fetch; delete window.e2; jest.restoreAllMocks() })

describe('NodeNotesByEditor — fetch + admin gate (#4528)', () => {
  it('fetches the admin endpoint and shows the search form on the empty shell', async () => {
    global.fetch = mockFetch({ success: 1, target_username: '', notes: [] })
    const { container } = render(<NodeNotesByEditor />)
    await waitFor(() => expect(container.querySelector('.node-notes-editor__form')).toBeTruthy())
    expect(global.fetch.mock.calls[0][0]).toMatch(/^\/api\/node_notes_by_editor\?/)
    expect(container.querySelector('input[name="targetUser"]')).toBeTruthy()
  })

  it('renders the admin hard-error copy when the API refuses', async () => {
    global.fetch = mockFetch({ success: 0, state: 'admin' })
    const { container } = render(<NodeNotesByEditor />)
    await waitFor(() => expect(container.textContent).toMatch(/restricted to administrators/i))
  })

  it('renders the user_not_found copy (built from the flag) plus the search form', async () => {
    setSearch('?targetUser=nobodyzzz&gotime=Go!')
    global.fetch = mockFetch({ success: 0, state: 'user_not_found', target_username: 'nobodyzzz' })
    const { container } = render(<NodeNotesByEditor />)
    await waitFor(() => expect(container.textContent).toMatch(/Could not find user 'nobodyzzz'/))
    expect(container.querySelector('.node-notes-editor__form')).toBeTruthy() // form still shown
  })

  it('renders the notes table for a found user', async () => {
    setSearch('?targetUser=root&gotime=Go!')
    global.fetch = mockFetch({
      success: 1, target_username: 'root', target_user_id: 113, total_count: 1, start: 0, limit: 50,
      notes: [{ node_id: 42, node_title: 'Some Node', note: 'a note', timestamp: '2026-06-20 12:00:00', author_id: 7, author_title: 'someauthor' }],
    })
    const { container } = render(<NodeNotesByEditor />)
    await waitFor(() => expect(container.querySelector('.node-notes-editor__table')).toBeTruthy())
    expect(container.textContent).toMatch(/Some Node/)
    expect(container.textContent).toMatch(/someauthor/)
    expect(container.querySelector('a[href="/?node_id=42"]')).toBeTruthy()
  })

  it('shows the empty-result copy when a found user has no notes', async () => {
    setSearch('?targetUser=root&gotime=Go!')
    global.fetch = mockFetch({
      success: 1, target_username: 'root', target_user_id: 113, total_count: 0, start: 0, limit: 50, notes: [],
    })
    const { container } = render(<NodeNotesByEditor />)
    await waitFor(() => expect(container.textContent).toMatch(/No node notes found/i))
  })
})

describe('NodeNotesByEditor — in-place search + pagination (#4528, no reload)', () => {
  it('submits the search in place: refetches with the typed user, pushes URL, no reload', async () => {
    const pushSpy = jest.spyOn(window.history, 'pushState').mockImplementation(() => {})
    global.fetch = mockFetch({ success: 1, target_username: '', notes: [] })
    const { container } = render(<NodeNotesByEditor />)
    await waitFor(() => expect(container.querySelector('.node-notes-editor__form')).toBeTruthy())

    fireEvent.change(container.querySelector('input[name="targetUser"]'), { target: { value: 'someeditor' } })
    fireEvent.submit(container.querySelector('.node-notes-editor__form'))
    await waitFor(() => expect(global.fetch.mock.calls.length).toBe(2))

    expect(window.location.href).toBe('http://localhost/?node_id=2117964') // no hard navigation
    expect(global.fetch.mock.calls[1][0]).toContain('targetUser=someeditor')
    expect(global.fetch.mock.calls[1][0]).toContain('gotime=Go') // Go! (URLSearchParams encodes the !)
    expect(pushSpy.mock.calls[pushSpy.mock.calls.length - 1][2]).toContain('targetUser=someeditor')
  })

  it('paginates in place: clicking Next refetches start=50 and pushes, no reload', async () => {
    setLocation('http://localhost/?node_id=2117964&targetUser=root&gotime=Go!')
    const pushSpy = jest.spyOn(window.history, 'pushState').mockImplementation(() => {})
    global.fetch = mockFetch({
      success: 1, target_username: 'root', target_user_id: 113, total_count: 120, start: 0, limit: 50,
      notes: [{ node_id: 42, node_title: 'Some Node', note: 'x', timestamp: '2026-06-20 12:00:00' }],
    })
    const { getAllByText } = render(<NodeNotesByEditor />)
    // pagination renders above AND below the table -> two "Next" links; use the first
    await waitFor(() => expect(getAllByText(/Next/).length).toBeGreaterThan(0))

    fireEvent.click(getAllByText(/Next/)[0])
    await waitFor(() => expect(global.fetch.mock.calls.length).toBe(2))

    expect(window.location.href).toBe('http://localhost/?node_id=2117964&targetUser=root&gotime=Go!')
    expect(global.fetch.mock.calls[1][0]).toContain('start=50')
    expect(pushSpy.mock.calls[pushSpy.mock.calls.length - 1][2]).toContain('start=50')
  })
})
