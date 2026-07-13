import React from 'react'
import { render, waitFor } from '@testing-library/react'
import NodesOfTheYear from './NodesOfTheYear'

// Fully client-resolved (#4524): the Page is a pure gate. NodesOfTheYear reads year/wutype/count/
// orderby off the URL and fetches GET /api/nodes_of_the_year.

const PAYLOAD = {
  success: 1, year: 2025, wutype: 0, count: 50, orderby: 'cooled DESC,reputation DESC',
  writeup_types: [{ node_id: 100, title: 'idea' }],
  writeups: [
    { writeup_id: 1, parent_id: 9, parent_title: 'A Node', type_title: 'idea',
      author_id: 7, author_title: 'alice', publishtime: '2025-06-01 00:00:00', cooled: 3, reputation: 42 }
  ]
}
const setSearch = (s) => { window.location.search = s }
const mockFetch = (p) => jest.fn(() => Promise.resolve({ json: () => Promise.resolve(p) }))

beforeEach(() => setSearch(''))
afterEach(() => { delete global.fetch; jest.restoreAllMocks() })

describe('NodesOfTheYear (fetch-driven)', () => {
  it('fetches /api/nodes_of_the_year with the URL filters and renders the table', async () => {
    setSearch('?year=2020&wutype=100&count=15&orderby=reputation%20DESC')
    global.fetch = mockFetch({ ...PAYLOAD, year: 2020 })
    const { container } = render(<NodesOfTheYear />)
    await waitFor(() => expect(container.querySelector('.nodes-of-year__table')).toBeTruthy())
    const url = global.fetch.mock.calls[0][0]
    expect(url).toContain('/api/nodes_of_the_year?')
    expect(url).toContain('year=2020'); expect(url).toContain('wutype=100')
    expect(url).toContain('count=15'); expect(url).toContain('orderby=reputation')
    expect(container.textContent).toMatch(/A Node/)
    expect(container.textContent).toMatch(/alice/)
    expect(container.textContent).toMatch(/3\/42/) // cooled/reputation
  })

  it('omits year from the fetch when the URL has none (API defaults it) and reflects it in the form', async () => {
    global.fetch = mockFetch(PAYLOAD) // year 2025
    const { container } = render(<NodesOfTheYear />)
    await waitFor(() => expect(container.querySelector('.nodes-of-year__table')).toBeTruthy())
    expect(global.fetch.mock.calls[0][0]).not.toContain('year=')
    expect(container.querySelector('input[type="number"]').value).toBe('2025')
  })

  it('shows a loading state before the fetch resolves', () => {
    global.fetch = jest.fn(() => new Promise(() => {}))
    const { container } = render(<NodesOfTheYear />)
    expect(container.textContent).toMatch(/Loading writeups/i)
  })
})
