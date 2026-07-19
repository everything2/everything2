import React from 'react'
import { render, waitFor } from '@testing-library/react'
import UserStatistics from './UserStatistics'

// Fetch-driven (#4546): the Page is a pure gate; GET /api/user_statistics on mount.
const jsonFetch = (p) => jest.fn(() => Promise.resolve({ json: () => Promise.resolve(p) }))

describe('UserStatistics (fetch-driven #4546)', () => {
  afterEach(() => { delete global.fetch; jest.restoreAllMocks() })

  it('fetches /api/user_statistics and renders the activity windows', async () => {
    global.fetch = jsonFetch({
      success: 1, total_users: 5, users_ever_logged_in: 4, users_last_24h: 1,
      users_last_week: 2, users_last_2weeks: 3, users_last_4weeks: 4
    })
    const { container } = render(<UserStatistics />)
    await waitFor(() => expect(container.textContent).toMatch(/total users registered/))
    expect(global.fetch.mock.calls[0][0]).toMatch(/^\/api\/user_statistics/)
    expect(container.textContent).toMatch(/last 24 hours/)
  })

  it('shows a restricted message on permission denied (admin-only)', async () => {
    global.fetch = jsonFetch({ success: 0, state: 'permission' })
    const { container } = render(<UserStatistics />)
    await waitFor(() => expect(container.textContent).toMatch(/restricted to administrators/i))
    expect(container.textContent).not.toMatch(/total users registered/)
  })
})
