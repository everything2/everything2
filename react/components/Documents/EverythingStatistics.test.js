import React from 'react'
import { render, waitFor } from '@testing-library/react'
import EverythingStatistics from './EverythingStatistics'

// Fetch-driven (#4546): the Page is a pure gate; GET /api/everything_statistics on mount.
const jsonFetch = (p) => jest.fn(() => Promise.resolve({ json: () => Promise.resolve(p) }))

describe('EverythingStatistics (fetch-driven #4546)', () => {
  afterEach(() => { delete global.fetch; jest.restoreAllMocks() })

  it('fetches /api/everything_statistics and renders the counts', async () => {
    global.fetch = jsonFetch({
      success: 1, total_nodes: 123, total_writeups: 45, total_users: 67, total_links: 89,
      finger_node_id: 111, news_node_id: 222
    })
    const { container } = render(<EverythingStatistics />)
    await waitFor(() => expect(container.textContent).toMatch(/Total Number of Nodes: 123/))
    expect(global.fetch.mock.calls[0][0]).toMatch(/^\/api\/everything_statistics/)
    expect(container.textContent).toMatch(/Total Number of Users: 67/)
  })

  it('shows a restricted message on permission denied (admin-only)', async () => {
    global.fetch = jsonFetch({ success: 0, state: 'permission' })
    const { container } = render(<EverythingStatistics />)
    await waitFor(() => expect(container.textContent).toMatch(/restricted to administrators/i))
    expect(container.textContent).not.toMatch(/Total Number of Nodes/)
  })
})
