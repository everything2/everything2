import React from 'react'
import { render, waitFor, fireEvent } from '@testing-library/react'
import NewsForNoders from './NewsForNoders'

// #4543: fetch-driven. GET /api/news_for_noders on mount; older/newer nav refetches in place via
// history.pushState. Admin/owner removal DELETEs /api/weblog/:weblog_id/:node_id.

const setLocation = (href) => {
  const u = new URL(href)
  window.location.href = href
  window.location.pathname = u.pathname
  window.location.search = u.search
}
const listFetch = (payload) => jest.fn(() => Promise.resolve({ json: () => Promise.resolve(payload) }))
const entry = { node_id: 42, title: 'Big News', author: 'alice', author_id: 7, linkedtime: '2026-01-02 10:00:00', content: 'the story', type: 'document' }

beforeEach(() => setLocation('http://localhost/?node_id=500'))
afterEach(() => { delete global.fetch; jest.restoreAllMocks() })

describe('NewsForNoders — fetch (#4543)', () => {
  it('renders entries fetched from the API', async () => {
    global.fetch = listFetch({ success: 1, entries: [entry], weblog_id: 1, can_remove: false, has_older: false, has_newer: false })
    const { container } = render(<NewsForNoders />)
    await waitFor(() => expect(container.textContent).toMatch(/Big News/))
    expect(container.textContent).toMatch(/alice/)
    expect(container.textContent).toMatch(/the story/)
    expect(global.fetch.mock.calls[0][0]).toMatch(/^\/api\/news_for_noders/)
  })

  it('renders the empty state', async () => {
    global.fetch = listFetch({ success: 1, entries: [], weblog_id: 1 })
    const { container } = render(<NewsForNoders />)
    await waitFor(() => expect(container.textContent).toMatch(/No news entries found/i))
  })

  it('renders the no_news_group error', async () => {
    global.fetch = listFetch({ success: 0, state: 'no_news_group', entries: [] })
    const { container } = render(<NewsForNoders />)
    await waitFor(() => expect(container.textContent).toMatch(/News usergroup not found/i))
  })

  it('shows the remove button only when can_remove', async () => {
    global.fetch = listFetch({ success: 1, entries: [entry], weblog_id: 1, can_remove: true })
    const { container } = render(<NewsForNoders />)
    await waitFor(() => expect(container.textContent).toMatch(/Big News/))
    expect(container.querySelector('.news-for-noders__remove-button')).toBeTruthy()
  })

  it('paginates older in place: refetches with nextweblog, pushes URL, no reload', async () => {
    const pushSpy = jest.spyOn(window.history, 'pushState').mockImplementation(() => {})
    global.fetch = listFetch({ success: 1, entries: [entry], weblog_id: 1, has_older: true, next_older: 20 })
    const { getByText } = render(<NewsForNoders />)
    await waitFor(() => expect(getByText(/older/i)).toBeInTheDocument())

    fireEvent.click(getByText(/older/i))
    await waitFor(() => expect(global.fetch.mock.calls.length).toBe(2))
    expect(window.location.href).toBe('http://localhost/?node_id=500') // no reload
    expect(global.fetch.mock.calls[1][0]).toContain('nextweblog=20')
    expect(pushSpy.mock.calls[pushSpy.mock.calls.length - 1][2]).toContain('nextweblog=20')
  })

  it('removes an entry via DELETE and drops it from the list', async () => {
    global.fetch = jest.fn((url, opts) =>
      (opts && opts.method === 'DELETE')
        ? Promise.resolve({ json: () => Promise.resolve({ success: 1 }) })
        : Promise.resolve({ json: () => Promise.resolve({ success: 1, entries: [entry], weblog_id: 77, can_remove: true }) })
    )
    const { container, getByText, queryByText } = render(<NewsForNoders />)
    await waitFor(() => expect(container.querySelector('.news-for-noders__remove-button')).toBeTruthy())

    fireEvent.click(container.querySelector('.news-for-noders__remove-button'))
    fireEvent.click(getByText('Remove')) // confirm in the modal
    await waitFor(() => expect(queryByText('Big News')).not.toBeInTheDocument())
    const del = global.fetch.mock.calls.find((c) => c[1] && c[1].method === 'DELETE')
    expect(del[0]).toBe('/api/weblog/77/42')
  })
})
