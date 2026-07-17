import React from 'react'
import { render, waitFor, fireEvent } from '@testing-library/react'
import NewsArchives from './NewsArchives'

// #4543: fetch-driven. GET /api/news_archives on mount; group-select + back refetch in place via
// WeblogViewer's onSelectGroup/onBack callbacks (history.pushState, no reload).

const setLocation = (href) => {
  const u = new URL(href)
  window.location.href = href
  window.location.pathname = u.pathname
  window.location.search = u.search
}
const listFetch = (payload) => jest.fn(() => Promise.resolve({ json: () => Promise.resolve(payload) }))
const groups = [{ node_id: 100, title: 'edev', count: 3 }, { node_id: 200, title: 'zebra', count: 0 }]

beforeEach(() => setLocation('http://localhost/?node_id=600'))
afterEach(() => { delete global.fetch; jest.restoreAllMocks() })

describe('NewsArchives — fetch (#4543)', () => {
  it('renders the group list from the API', async () => {
    global.fetch = listFetch({ success: 1, groups, viewWeblog: null })
    const { container } = render(<NewsArchives user={{}} />)
    await waitFor(() => expect(container.textContent).toMatch(/edev/))
    expect(global.fetch.mock.calls[0][0]).toMatch(/^\/api\/news_archives/)
    expect(container.textContent).toMatch(/zebra/)
  })

  it('renders a viewed group with its entries', async () => {
    setLocation('http://localhost/?node_id=600&view_weblog=100')
    global.fetch = listFetch({
      success: 1, groups, viewWeblog: 100, viewGroupName: 'edev',
      entries: [{ node_id: 42, title: 'A Pick', timestamp: '2026-01-01', linker_id: 7, linker_name: 'alice' }], skippedCount: 0
    })
    const { container } = render(<NewsArchives user={{}} />)
    await waitFor(() => expect(container.textContent).toMatch(/Viewing items for/))
    expect(container.textContent).toMatch(/A Pick/)
  })

  it('renders the permission error from the state', async () => {
    setLocation('http://localhost/?node_id=600&view_weblog=114')
    global.fetch = listFetch({ success: 0, state: 'permission', groups, viewWeblog: null })
    const { container } = render(<NewsArchives user={{}} />)
    await waitFor(() => expect(container.textContent).toMatch(/do not have permission/i))
  })

  it('selects a group in place via WeblogViewer: refetches with view_weblog, no reload', async () => {
    const pushSpy = jest.spyOn(window.history, 'pushState').mockImplementation(() => {})
    global.fetch = listFetch({ success: 1, groups, viewWeblog: null })
    const { getByText } = render(<NewsArchives user={{}} />)
    await waitFor(() => expect(getByText('edev')).toBeInTheDocument())

    fireEvent.click(getByText('edev'))
    await waitFor(() => expect(global.fetch.mock.calls.length).toBe(2))
    expect(window.location.href).toBe('http://localhost/?node_id=600') // no reload
    expect(global.fetch.mock.calls[1][0]).toContain('view_weblog=100')
    expect(pushSpy.mock.calls[pushSpy.mock.calls.length - 1][2]).toContain('view_weblog=100')
  })
})
