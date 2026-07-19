import React from 'react'
import { render, waitFor } from '@testing-library/react'
import RegistryInformation from './RegistryInformation'

// Fetch-driven (#4548): GET /api/registry_information on mount. Login-required -> state:'guest'.
const jsonFetch = (p) => jest.fn(() => Promise.resolve({ json: () => Promise.resolve(p) }))
afterEach(() => { delete global.fetch; jest.restoreAllMocks() })

describe('RegistryInformation (fetch-driven #4548)', () => {
  it('fetches and renders the user entries', async () => {
    global.fetch = jsonFetch({
      success: 1, has_entries: true,
      entries: [{ registry: { node_id: 5, title: 'Loc' }, data: 'NYC', comments: 'hi', in_profile: true }]
    })
    const { container } = render(<RegistryInformation />)
    await waitFor(() => expect(container.textContent).toMatch(/Loc/))
    expect(global.fetch.mock.calls[0][0]).toMatch(/^\/api\/registry_information/)
    expect(container.textContent).toMatch(/NYC/)
  })

  it('renders the empty state', async () => {
    global.fetch = jsonFetch({ success: 1, has_entries: false, entries: [] })
    const { container } = render(<RegistryInformation />)
    await waitFor(() => expect(container.textContent).toMatch(/haven't submitted any registry entries/i))
  })

  it('shows the guest message on state:guest', async () => {
    global.fetch = jsonFetch({ success: 0, state: 'guest' })
    const { container } = render(<RegistryInformation />)
    await waitFor(() => expect(container.textContent).toMatch(/if you logged in/i))
  })
})
