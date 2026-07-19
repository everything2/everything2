import React from 'react'
import { render, waitFor } from '@testing-library/react'
import EverythingSRichestNoders from './EverythingSRichestNoders'

// Fetch-driven (#4546): the Page is a pure gate; GET /api/everything_s_richest_noders on mount.
const jsonFetch = (p) => jest.fn(() => Promise.resolve({ json: () => Promise.resolve(p) }))

describe('EverythingSRichestNoders (fetch-driven #4546)', () => {
  afterEach(() => { delete global.fetch; jest.restoreAllMocks() })

  it('fetches the leaderboard and renders the sections + stats', async () => {
    global.fetch = jsonFetch({
      success: 1, total_gp: 10000,
      richest_all: [{ user_id: 1, title: 'alice', gp: 5000 }],
      poorest: [{ user_id: 2, title: 'bob', gp: 1 }],
      richest_top: [{ user_id: 1, title: 'alice', gp: 5000 }],
      richest_top_gp: 5000, top_percentage: 50, limit_all: 1500, limit_top: 10
    })
    const { container } = render(<EverythingSRichestNoders />)
    await waitFor(() => expect(container.textContent).toMatch(/1500 Richest Noders/))
    expect(global.fetch.mock.calls[0][0]).toMatch(/^\/api\/everything_s_richest_noders/)
    expect(container.textContent).toMatch(/hold 50\.00% of all the GP/)
  })

  it('shows a restricted message on permission denied (admin-only)', async () => {
    global.fetch = jsonFetch({ success: 0, state: 'permission' })
    const { container } = render(<EverythingSRichestNoders />)
    await waitFor(() => expect(container.textContent).toMatch(/restricted to administrators/i))
    expect(container.textContent).not.toMatch(/Richest Noders/)
  })
})
