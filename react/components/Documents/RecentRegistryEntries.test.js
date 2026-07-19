import React from 'react'
import { render, waitFor } from '@testing-library/react'
import RecentRegistryEntries from './RecentRegistryEntries'

// Fetch-driven (#4548): GET /api/recent_registry_entries on mount. Login-required -> state:'guest'.
const jsonFetch = (p) => jest.fn(() => Promise.resolve({ json: () => Promise.resolve(p) }))
afterEach(() => { delete global.fetch; jest.restoreAllMocks() })

describe('RecentRegistryEntries (fetch-driven #4548)', () => {
  it('fetches and renders recent entries', async () => {
    global.fetch = jsonFetch({
      success: 1,
      entries: [{ registry: { node_id: 5, title: 'Loc' }, user: { node_id: 7, title: 'alice' }, data: 'NYC', comments: '', in_profile: false, timestamp: '2026-01-01' }]
    })
    const { container } = render(<RecentRegistryEntries />)
    await waitFor(() => expect(container.textContent).toMatch(/Loc/))
    expect(global.fetch.mock.calls[0][0]).toMatch(/^\/api\/recent_registry_entries/)
    expect(container.textContent).toMatch(/alice/)
  })

  it('shows the guest message on state:guest', async () => {
    global.fetch = jsonFetch({ success: 0, state: 'guest' })
    const { container } = render(<RecentRegistryEntries />)
    await waitFor(() => expect(container.textContent).toMatch(/if you logged in/i))
  })
})
