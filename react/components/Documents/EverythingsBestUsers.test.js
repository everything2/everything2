import React from 'react'
import { render, waitFor } from '@testing-library/react'
import EverythingsBestUsers from './EverythingsBestUsers'

// Fully client-resolved (#4526): the Page is a pure gate. This reads the toggle filters off the URL
// and fetches GET /api/everything_s_best_users.

const PAYLOAD = {
  success: 1, showDevotion: 0, showAddiction: 0, showNewUsers: 0, showRecent: 0,
  users: [
    { node_id: 1, title: 'alice', experience: 5000, devotion: 100, addiction: 1.5, writeup_count: 50, level_value: 7, level_title: 'Sage' },
    { node_id: 2, title: 'bob', experience: 3000, devotion: 60, addiction: 0.8, writeup_count: 30, level_value: 5, level_title: 'Scribe' }
  ]
}
const setSearch = (s) => { window.location.search = s }
const mockFetch = (p) => jest.fn(() => Promise.resolve({ json: () => Promise.resolve(p) }))

beforeEach(() => setSearch(''))
afterEach(() => { delete global.fetch; jest.restoreAllMocks() })

describe('EverythingsBestUsers (fetch-driven)', () => {
  it('fetches /api/everything_s_best_users and renders the ranked table', async () => {
    global.fetch = mockFetch(PAYLOAD)
    const { container } = render(<EverythingsBestUsers />)
    await waitFor(() => expect(container.querySelector('.ebu__table')).toBeTruthy())
    expect(global.fetch.mock.calls[0][0]).toContain('/api/everything_s_best_users?')
    expect(container.textContent).toMatch(/alice/)
    expect(container.textContent).toMatch(/2 users ranked by experience/)
    expect(container.querySelectorAll('.ebu__table tbody tr')).toHaveLength(2)
  })

  it('carries the toggle filters from the URL into the fetch and label', async () => {
    setSearch('?ebu_showdevotion=1')
    global.fetch = mockFetch({ ...PAYLOAD, showDevotion: 1 })
    const { container } = render(<EverythingsBestUsers />)
    await waitFor(() => expect(container.textContent).toMatch(/ranked by devotion/))
    expect(global.fetch.mock.calls[0][0]).toContain('ebu_showdevotion=1')
    // the sort column header reflects the toggle
    expect(container.textContent).toMatch(/Devotion/)
  })

  it('renders the empty state when no users match', async () => {
    global.fetch = mockFetch({ ...PAYLOAD, users: [] })
    const { container } = render(<EverythingsBestUsers />)
    await waitFor(() => expect(container.textContent).toMatch(/No users found matching/))
  })

  it('shows a loading state before the fetch resolves', () => {
    global.fetch = jest.fn(() => new Promise(() => {}))
    const { container } = render(<EverythingsBestUsers />)
    expect(container.textContent).toMatch(/Loading/i)
  })
})
