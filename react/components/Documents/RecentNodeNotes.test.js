import React from 'react'
import { render, fireEvent, waitFor } from '@testing-library/react'
import RecentNodeNotes from './RecentNodeNotes'

// Fully client-resolved (#4528): the Page is a pure gate. RecentNodeNotes reads the toggles/page off
// the URL and fetches GET /api/recent_node_notes (editor-gated). The copy/badges/attribution are
// owned by the component; the #4389 behaviors (noter, lifecycle badge, default-hide, UTC time,
// query-preserving navigation) are re-pinned here against the fetch flow.

const setLocation = (href) => {
  const u = new URL(href)
  window.location.href = href
  window.location.pathname = u.pathname
  window.location.search = u.search
}
const mockFetch = (payload) => jest.fn(() => Promise.resolve({ json: () => Promise.resolve(payload) }))

const baseData = (overrides = {}) => ({
  success: 1, notes: [], total: 0, page: 0, perpage: 50,
  onlymynotes: 0, hidesystemnotes: 1, ...overrides,
})

beforeEach(() => setLocation('http://localhost/node/1429619'))
afterEach(() => { delete global.fetch; jest.restoreAllMocks() })

describe('RecentNodeNotes — fetch + gate (#4528)', () => {
  it('fetches the editor-gated endpoint and mounts', async () => {
    global.fetch = mockFetch(baseData())
    const { container } = render(<RecentNodeNotes />)
    await waitFor(() => expect(container.textContent).not.toMatch(/Loading/))
    expect(global.fetch.mock.calls[0][0]).toMatch(/^\/api\/recent_node_notes\?/)
  })

  it('shows the staff error when the API refuses (success:0)', async () => {
    global.fetch = mockFetch({ success: 0, state: 'staff' })
    const { container } = render(<RecentNodeNotes />)
    await waitFor(() => expect(container.textContent).toMatch(/available to staff/i))
  })
})

// #4389 behaviors, re-pinned against the fetch flow.
describe('RecentNodeNotes — author + lifecycle badge (#4389)', () => {
  it('relabels the filter "Hide automated notes" and checks it by default', async () => {
    global.fetch = mockFetch(baseData())
    const { getByLabelText } = render(<RecentNodeNotes />)
    await waitFor(() => expect(getByLabelText(/hide automated notes/i)).toBeChecked())
  })

  it('shows the noter as attribution and badges only the auto note', async () => {
    global.fetch = mockFetch(baseData({
      total: 2,
      notes: [
        { node: { node_id: 10, title: 'Apple' }, timestamp: '2026-06-20 12:00:00', note: 'Published from draft', noter: 'Glowing Fish', kind: 'auto' },
        { node: { node_id: 11, title: 'Banana' }, timestamp: '2026-06-20 13:00:00', note: 'Add sources please', noter: 'editorperson', kind: 'editorial' },
      ],
    }))
    const { getByText, container } = render(<RecentNodeNotes />)
    await waitFor(() => expect(getByText('Glowing Fish')).toBeInTheDocument())
    expect(getByText('editorperson')).toBeInTheDocument()
    expect(container.querySelectorAll('.recent-node-notes__badge')).toHaveLength(1)
  })

  it('formats the timestamp via the UTC date util (no "Invalid Date")', async () => {
    global.fetch = mockFetch(baseData({
      total: 1,
      notes: [{ node: { node_id: 10, title: 'Apple' }, timestamp: '2026-06-20 12:00:00', note: 'x', noter: 'someone', kind: 'editorial' }],
    }))
    const { container } = render(<RecentNodeNotes />)
    await waitFor(() => expect(container.querySelector('.recent-node-notes__timestamp')).toBeTruthy())
    const ts = container.querySelector('.recent-node-notes__timestamp').textContent
    expect(ts).not.toMatch(/invalid date/i)
    expect(ts).toMatch(/2026/)
  })

  it('does not badge or attribute a bare system note (no noter, editorial kind absent)', async () => {
    global.fetch = mockFetch(baseData({
      total: 1,
      notes: [{ node: { node_id: 10, title: 'Apple' }, timestamp: '2026-06-20 12:00:00', note: 'legacy note', kind: 'auto' }],
    }))
    const { container } = render(<RecentNodeNotes />)
    await waitFor(() => expect(container.querySelector('.recent-node-notes__badge')).toBeTruthy())
    expect(container.querySelectorAll('.recent-node-notes__badge')).toHaveLength(1)
    expect(container.querySelector('.recent-node-notes__noter')).toBeNull()
  })
})

// #4528: toggling a filter refetches IN PLACE (no full page reload). The URL is kept in sync via
// history.pushState so it stays shareable/back-button-friendly. #4389: a superdoc's identity lives
// in the query string (/index.pl?node=...&type=superdoc); the pushed URL must preserve path AND
// existing query, not bounce to the homepage.
describe('RecentNodeNotes — filter toggles refetch in place (#4528) + preserve the page (#4389)', () => {
  it('does NOT reload: toggling a filter refetches and pushes the URL, href unchanged', async () => {
    setLocation('http://localhost/index.pl?node=Recent+Node+Notes&type=superdoc')
    const pushSpy = jest.spyOn(window.history, 'pushState').mockImplementation(() => {})
    global.fetch = mockFetch(baseData())
    const { getByLabelText } = render(<RecentNodeNotes />)
    await waitFor(() => expect(getByLabelText(/hide automated notes/i)).toBeInTheDocument())

    fireEvent.click(getByLabelText(/hide automated notes/i)) // checked -> unchecked
    await waitFor(() => expect(global.fetch.mock.calls.length).toBe(2)) // mount + refetch, no reload

    // window.location.href never reassigned (no hard navigation)
    expect(window.location.href).toBe('http://localhost/index.pl?node=Recent+Node+Notes&type=superdoc')
    // the refetch asked the API for the new filter state
    expect(global.fetch.mock.calls[1][0]).toContain('hidesystemnotes=0')
    // the pushed URL preserved the superdoc identity and applied the filter
    const pushed = pushSpy.mock.calls[pushSpy.mock.calls.length - 1][2]
    expect(pushed).toContain('node=Recent')
    expect(pushed).toContain('type=superdoc')
    expect(pushed).toContain('hidesystemnotes=0')
    expect(pushed.startsWith('/index.pl')).toBe(true)
  })

  it('keeps a /node/<id> path identity when toggling a filter', async () => {
    setLocation('http://localhost/node/1429619')
    const pushSpy = jest.spyOn(window.history, 'pushState').mockImplementation(() => {})
    global.fetch = mockFetch(baseData())
    const { getByLabelText } = render(<RecentNodeNotes />)
    await waitFor(() => expect(getByLabelText(/show only my notes/i)).toBeInTheDocument())

    fireEvent.click(getByLabelText(/show only my notes/i))
    await waitFor(() => expect(global.fetch.mock.calls.length).toBe(2))

    expect(window.location.href).toBe('http://localhost/node/1429619')
    expect(global.fetch.mock.calls[1][0]).toContain('onlymynotes=1')
    const pushed = pushSpy.mock.calls[pushSpy.mock.calls.length - 1][2]
    expect(pushed.startsWith('/node/1429619')).toBe(true)
    expect(pushed).toContain('onlymynotes=1')
  })

  it('paginates in place: clicking Next refetches page 1 and pushes, no reload', async () => {
    setLocation('http://localhost/node/1429619')
    const pushSpy = jest.spyOn(window.history, 'pushState').mockImplementation(() => {})
    // total 120 across perpage 50 -> 3 pages, so page 0 has a Next
    global.fetch = mockFetch(baseData({ total: 120, notes: [
      { node: { node_id: 10, title: 'Apple' }, timestamp: '2026-06-20 12:00:00', note: 'x', noter: 'a', kind: 'editorial' }
    ] }))
    const { getByText } = render(<RecentNodeNotes />)
    await waitFor(() => expect(getByText(/Next/)).toBeInTheDocument())

    fireEvent.click(getByText(/Next/))
    await waitFor(() => expect(global.fetch.mock.calls.length).toBe(2))

    expect(window.location.href).toBe('http://localhost/node/1429619')
    expect(global.fetch.mock.calls[1][0]).toContain('page=1')
    expect(pushSpy.mock.calls[pushSpy.mock.calls.length - 1][2]).toContain('page=1')
  })
})
