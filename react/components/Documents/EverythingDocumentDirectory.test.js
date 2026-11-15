import React from 'react'
import { render, waitFor, fireEvent } from '@testing-library/react'
import EverythingDocumentDirectory from './EverythingDocumentDirectory'

// Fetch-driven (#4557): the Page is a pure gate. Filters are read off the URL and sent to
// GET /api/everything_document_directory; applying them refetches in place (pushState) rather than
// POSTing the page. Login-required -> state:'guest'.

const setLocation = (href) => {
  const u = new URL(href)
  window.location.href = href
  window.location.pathname = u.pathname
  window.location.search = u.search
}
const jsonFetch = (p) => jest.fn(() => Promise.resolve({ json: () => Promise.resolve(p) }))

const payload = (over = {}) => ({
  success: 1,
  documents: [{ node_id: 11, title: 'A Doc', author: 'alice', type: 'superdoc', createtime: '2026-01-02 03:04:05' }],
  total_count: 2, shown_count: 1, limit: 60, current_sort: '0',
  filter_user: '', filter_nodetype: '', available_nodetypes: ['superdoc', 'document'],
  is_developer: false, ...over
})

beforeEach(() => setLocation('http://localhost/?node_id=800'))
afterEach(() => { delete global.fetch; jest.restoreAllMocks() })

describe('EverythingDocumentDirectory (fetch-driven #4557)', () => {
  it('fetches and renders the document list', async () => {
    global.fetch = jsonFetch(payload())
    const { container } = render(<EverythingDocumentDirectory user={{}} e2={{}} />)
    await waitFor(() => expect(container.textContent).toMatch(/A Doc/))
    expect(global.fetch.mock.calls[0][0]).toMatch(/^\/api\/everything_document_directory/)
  })

  it('shows the login message on state:guest', async () => {
    global.fetch = jsonFetch({ success: 0, state: 'guest' })
    const { container } = render(<EverythingDocumentDirectory user={{}} e2={{}} />)
    await waitFor(() => expect(container.textContent).toMatch(/log in first/i))
  })

  it('sends filters from the URL on mount', async () => {
    setLocation('http://localhost/?node_id=800&filter_nodetype=superdoc&filter_user=alice')
    global.fetch = jsonFetch(payload({ filter_nodetype: 'superdoc', filter_user: 'alice' }))
    render(<EverythingDocumentDirectory user={{}} e2={{}} />)
    await waitFor(() => expect(global.fetch.mock.calls.length).toBe(1))
    const url = global.fetch.mock.calls[0][0]
    expect(url).toContain('filter_nodetype=superdoc')
    expect(url).toContain('filter_user=alice')
  })

  it('applying a filter refetches in place and pushes the URL — no page POST', async () => {
    const pushSpy = jest.spyOn(window.history, 'pushState').mockImplementation(() => {})
    global.fetch = jsonFetch(payload())
    const { container } = render(<EverythingDocumentDirectory user={{}} e2={{}} />)
    await waitFor(() => expect(container.querySelector('.doc-directory__form')).toBeTruthy())

    fireEvent.change(container.querySelector('input[name="filter_user"]'), { target: { value: 'bob' } })
    fireEvent.submit(container.querySelector('.doc-directory__form'))

    // one preference POST + the refetch
    await waitFor(() => expect(global.fetch.mock.calls.length).toBeGreaterThanOrEqual(3))
    expect(window.location.href).toBe('http://localhost/?node_id=800') // no reload
    const prefCall = global.fetch.mock.calls.find((c) => String(c[0]).includes('/api/preferences/set'))
    expect(prefCall).toBeTruthy()
    const last = global.fetch.mock.calls[global.fetch.mock.calls.length - 1][0]
    expect(last).toContain('filter_user=bob')
    expect(pushSpy.mock.calls[pushSpy.mock.calls.length - 1][2]).toContain('filter_user=bob')
  })

  // is_admin/is_editor come from the global e2.user prop (#4390); is_developer from the API.
  it('admin + editor user sees the node_id column and the List Nodes link', async () => {
    global.fetch = jsonFetch(payload())
    const { container } = render(<EverythingDocumentDirectory user={{ admin: true, editor: true }} e2={{}} />)
    await waitFor(() => expect(container.textContent).toMatch(/A Doc/))
    expect(container.textContent).toMatch(/List Nodes of Type/)
  })

  it('non-admin non-editor user hides the List Nodes link', async () => {
    global.fetch = jsonFetch(payload())
    const { container } = render(<EverythingDocumentDirectory user={{ admin: false, editor: false }} e2={{}} />)
    await waitFor(() => expect(container.textContent).toMatch(/A Doc/))
    expect(container.textContent).not.toMatch(/List Nodes of Type/)
  })

  it('undefined user prop does not crash and gates off the privileged bits', async () => {
    global.fetch = jsonFetch(payload())
    const { container } = render(<EverythingDocumentDirectory e2={{}} />)
    await waitFor(() => expect(container.textContent).toMatch(/A Doc/))
    expect(container.textContent).not.toMatch(/List Nodes of Type/)
  })

  it('the sort <select> carries no form name (not POSTed as a page param, #4416)', async () => {
    global.fetch = jsonFetch(payload())
    const { container } = render(<EverythingDocumentDirectory user={{}} e2={{}} />)
    await waitFor(() => expect(container.querySelector('.doc-directory__select')).toBeTruthy())
    expect(container.querySelector('.doc-directory__select').getAttribute('name')).toBeNull()
  })

  it('"show all" refetches with edd_limit set to the total', async () => {
    jest.spyOn(window.history, 'pushState').mockImplementation(() => {})
    global.fetch = jsonFetch(payload({ total_count: 42, shown_count: 1 }))
    const { container, getByText } = render(<EverythingDocumentDirectory user={{}} e2={{}} />)
    await waitFor(() => expect(container.textContent).toMatch(/A Doc/))

    fireEvent.click(getByText('42'))
    await waitFor(() => expect(global.fetch.mock.calls.length).toBe(2))
    expect(global.fetch.mock.calls[1][0]).toContain('edd_limit=42')
  })
})
