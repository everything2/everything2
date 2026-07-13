import React from 'react'
import { render, waitFor } from '@testing-library/react'
import WriteupsByType from './WriteupsByType'

// Fully client-resolved (#4524): the Page is a pure gate. WriteupsByType reads wutype/count/page off
// the URL and fetches GET /api/writeups_by_type.

const PAYLOAD = {
  success: 1,
  writeups: [
    { node_id: 42, title: 'A Node', writeup_type: 'idea', publishtime: '2026-01-02 03:04:05',
      author: { node_id: 7, title: 'alice' }, parent: { node_id: 9, title: 'A Node' } }
  ],
  type_options: [{ value: 0, label: 'All' }, { value: 100, label: 'idea' }],
  current_type: 0, current_type_name: 'All', current_count: 50, current_page: 0
}
const setSearch = (s) => { window.location.search = s }
const mockFetch = (p) => jest.fn(() => Promise.resolve({ json: () => Promise.resolve(p) }))

beforeEach(() => setSearch(''))
afterEach(() => { delete global.fetch; jest.restoreAllMocks() })

describe('WriteupsByType (fetch-driven)', () => {
  it('fetches /api/writeups_by_type with the URL filters and renders the table', async () => {
    setSearch('?wutype=100&count=25&page=1')
    global.fetch = mockFetch(PAYLOAD)
    const { container } = render(<WriteupsByType />)
    await waitFor(() => expect(container.querySelector('.writeups-by-type__table')).toBeTruthy())
    const url = global.fetch.mock.calls[0][0]
    expect(url).toContain('/api/writeups_by_type?')
    expect(url).toContain('wutype=100'); expect(url).toContain('count=25'); expect(url).toContain('page=1')
    expect(container.textContent).toMatch(/A Node/)
    expect(container.textContent).toMatch(/alice/)
  })

  it('shows a loading state before the fetch resolves', () => {
    global.fetch = jest.fn(() => new Promise(() => {}))
    const { container } = render(<WriteupsByType />)
    expect(container.textContent).toMatch(/Loading writeups/i)
  })

  it('renders the static per-page count options (owned by React)', async () => {
    global.fetch = mockFetch(PAYLOAD)
    const { container } = render(<WriteupsByType />)
    await waitFor(() => expect(container.querySelector('select[name="count"]')).toBeTruthy())
    const opts = [...container.querySelectorAll('select[name="count"] option')].map((o) => o.value)
    expect(opts).toEqual(['10', '25', '50', '75', '100', '150', '200', '250', '500'])
  })

  it('populates the type dropdown from the API type_options', async () => {
    global.fetch = mockFetch(PAYLOAD)
    const { container } = render(<WriteupsByType />)
    await waitFor(() => expect(container.querySelector('select[name="wutype"]')).toBeTruthy())
    expect(container.textContent).toMatch(/idea/)
  })
})
