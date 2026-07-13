import React from 'react'
import { render, waitFor } from '@testing-library/react'
import HomenodeInspector from './HomenodeInspector'

// Fully client-resolved (#4526): the Page is a pure gate. HomenodeInspector reads the filters off the
// URL and fetches GET /api/homenode_inspector (admin-gated).

const PAYLOAD = {
  success: 1, total: 2, per_page: 10, total_pages: 1, page: 1, pole_id: 500,
  filters: { gonetime: 0, goneunit: 'MONTH', showlength: 1000, maxwus: 5, extlinks: 0, dotstoo: 0 },
  items: [
    { node_id: 11, title: 'spammer1', doctext: '[http://x] buy stuff', full_length: 20 },
    { node_id: 12, title: 'spammer2', doctext: '...', full_length: 3 }
  ]
}
const setSearch = (s) => { window.location.search = s }
const mockFetch = (p) => jest.fn(() => Promise.resolve({ json: () => Promise.resolve(p) }))

beforeEach(() => setSearch(''))
afterEach(() => { delete global.fetch; jest.restoreAllMocks() })

describe('HomenodeInspector (fetch-driven)', () => {
  it('fetches /api/homenode_inspector with the URL filters and renders the results', async () => {
    setSearch('?gonetime=3&goneunit=year&maxwus=5&extlinks=1')
    global.fetch = mockFetch(PAYLOAD)
    const { container } = render(<HomenodeInspector />)
    await waitFor(() => expect(container.textContent).toMatch(/Found 2 matching/))
    const url = global.fetch.mock.calls[0][0]
    expect(url).toContain('/api/homenode_inspector?')
    expect(url).toContain('gonetime=3'); expect(url).toContain('goneunit=year')
    expect(url).toContain('maxwus=5'); expect(url).toContain('extlinks=1')
    expect(container.textContent).toMatch(/spammer1/)
    expect(container.querySelector('.homenode-inspector__options')).toBeTruthy()
  })

  it('shows the admin gate message on the admin error state', async () => {
    global.fetch = mockFetch({ success: 0, state: 'admin' })
    const { container } = render(<HomenodeInspector />)
    await waitFor(() => expect(container.textContent).toMatch(/restricted to administrators/i))
  })

  it('shows the parameter-error message on the param error state', async () => {
    global.fetch = mockFetch({ success: 0, state: 'param' })
    const { container } = render(<HomenodeInspector />)
    await waitFor(() => expect(container.textContent).toMatch(/Parameter error/i))
  })

  it('shows a loading state before the fetch resolves', () => {
    global.fetch = jest.fn(() => new Promise(() => {}))
    const { container } = render(<HomenodeInspector />)
    expect(container.textContent).toMatch(/Loading/i)
  })
})
