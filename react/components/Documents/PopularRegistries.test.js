import React from 'react'
import { render, waitFor } from '@testing-library/react'
import PopularRegistries from './PopularRegistries'

// Fetch-driven (#4550): the Page is a pure gate; GET /api/popular_registries on mount.
const jsonFetch = (p) => jest.fn(() => Promise.resolve({ json: () => Promise.resolve(p) }))
afterEach(() => { delete global.fetch; jest.restoreAllMocks() })

describe('PopularRegistries (fetch-driven #4550)', () => {
  it('fetches and renders the ranked registries', async () => {
    global.fetch = jsonFetch({ success: 1, limit: 25, registries: [
      { node_id: 5, title: 'Noders by Location', submission_count: 4 },
      { node_id: 6, title: 'Coffee or Tea', submission_count: 2 }
    ] })
    const { container } = render(<PopularRegistries />)
    await waitFor(() => expect(container.textContent).toMatch(/Noders by Location/))
    expect(global.fetch.mock.calls[0][0]).toMatch(/^\/api\/popular_registries/)
    expect(container.textContent).toMatch(/Coffee or Tea/)
  })

  it('renders the empty state', async () => {
    global.fetch = jsonFetch({ success: 1, limit: 25, registries: [] })
    const { container } = render(<PopularRegistries />)
    await waitFor(() => expect(container.textContent).toMatch(/No registries found/))
  })
})
