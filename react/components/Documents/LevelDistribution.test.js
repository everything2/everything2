import React from 'react'
import { render, waitFor } from '@testing-library/react'
import LevelDistribution from './LevelDistribution'

// Fetch-driven (#4546): the Page is a pure gate; GET /api/level_distribution on mount.
const jsonFetch = (p) => jest.fn(() => Promise.resolve({ json: () => Promise.resolve(p) }))

describe('LevelDistribution (fetch-driven #4546)', () => {
  afterEach(() => { delete global.fetch; jest.restoreAllMocks() })

  it('fetches and renders the level rows', async () => {
    global.fetch = jsonFetch({ success: 1, levels: [{ level: 5, title: 'Guru', count: 12 }] })
    const { container } = render(<LevelDistribution />)
    await waitFor(() => expect(container.textContent).toMatch(/active E2 users at each level/))
    expect(global.fetch.mock.calls[0][0]).toMatch(/^\/api\/level_distribution/)
    expect(container.textContent).toMatch(/Guru/)
    expect(container.textContent).toMatch(/12/)
  })

  it('renders the empty state', async () => {
    global.fetch = jsonFetch({ success: 1, levels: [] })
    const { container } = render(<LevelDistribution />)
    await waitFor(() => expect(container.textContent).toMatch(/No active users found/))
  })
})
