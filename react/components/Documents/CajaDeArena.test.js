import React from 'react'
import { render, waitFor } from '@testing-library/react'
import CajaDeArena from './CajaDeArena'

// Fully client-resolved (#4526): the Page is a pure gate. CajaDeArena reads filters off the URL and
// fetches GET /api/caja_de_arena (admin-gated).

const PAYLOAD = {
  success: 1, total: 1, per_page: 10, total_pages: 1, page: 1, pole_id: 500,
  filters: { gonesince: '2 MONTH', showlength: 1000, published: 0, extlinks: 0 },
  items: [{ node_id: 21, title: 'sandboxspammer', doctext: 'spam', full_length: 4 }]
}
const setSearch = (s) => { window.location.search = s }
const mockFetch = (p) => jest.fn(() => Promise.resolve({ json: () => Promise.resolve(p) }))

beforeEach(() => setSearch(''))
afterEach(() => { delete global.fetch; jest.restoreAllMocks() })

describe('CajaDeArena (fetch-driven)', () => {
  it('fetches /api/caja_de_arena with the URL filters and renders the results', async () => {
    setSearch('?gonesince=' + encodeURIComponent('2 MONTH') + '&published=1')
    global.fetch = mockFetch(PAYLOAD)
    const { container } = render(<CajaDeArena />)
    await waitFor(() => expect(container.textContent).toMatch(/Spam entries: 1 found/))
    const url = global.fetch.mock.calls[0][0]
    expect(url).toContain('/api/caja_de_arena?')
    expect(url).toContain('published=1')
    expect(container.textContent).toMatch(/sandboxspammer/)
  })

  it('combines the number + unit controls into a single gonesince hidden field (old form bug)', async () => {
    setSearch('?gonesince=' + encodeURIComponent('3 WEEK'))
    global.fetch = mockFetch({ ...PAYLOAD, filters: { ...PAYLOAD.filters, gonesince: '3 WEEK' } })
    const { container } = render(<CajaDeArena />)
    await waitFor(() => expect(container.querySelector('.caja__fieldset')).toBeTruthy())
    const hidden = container.querySelector('input[name="gonesince"]')
    expect(hidden.value).toBe('3 WEEK')
  })

  it('shows the admin gate message on the admin error state', async () => {
    global.fetch = mockFetch({ success: 0, state: 'admin' })
    const { container } = render(<CajaDeArena />)
    await waitFor(() => expect(container.textContent).toMatch(/restricted to administrators/i))
  })

  it('shows a loading state before the fetch resolves', () => {
    global.fetch = jest.fn(() => new Promise(() => {}))
    const { container } = render(<CajaDeArena />)
    expect(container.textContent).toMatch(/Loading/i)
  })
})
