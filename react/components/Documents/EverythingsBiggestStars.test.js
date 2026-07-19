import React from 'react'
import { render, waitFor } from '@testing-library/react'
import EverythingsBiggestStars from './EverythingsBiggestStars'

// Fetch-driven (#4546): the Page is a pure gate; GET /api/everything_s_biggest_stars on mount.
const jsonFetch = (p) => jest.fn(() => Promise.resolve({ json: () => Promise.resolve(p) }))

describe('EverythingsBiggestStars (fetch-driven #4546)', () => {
  afterEach(() => { delete global.fetch; jest.restoreAllMocks() })

  it('fetches and renders the starred users', async () => {
    global.fetch = jsonFetch({ success: 1, limit: 100, users: [{ node_id: 7, title: 'alice', stars: 3 }] })
    const { container } = render(<EverythingsBiggestStars />)
    await waitFor(() => expect(container.textContent).toMatch(/100 Most Starred Noders/))
    expect(global.fetch.mock.calls[0][0]).toMatch(/^\/api\/everything_s_biggest_stars/)
    expect(container.textContent).toMatch(/alice/)
    expect(container.textContent).toMatch(/3 stars/)
  })

  it('renders the empty state', async () => {
    global.fetch = jsonFetch({ success: 1, limit: 100, users: [] })
    const { container } = render(<EverythingsBiggestStars />)
    await waitFor(() => expect(container.textContent).toMatch(/No users with stars found/))
  })
})
