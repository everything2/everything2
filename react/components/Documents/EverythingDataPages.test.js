import React from 'react'
import { render, waitFor } from '@testing-library/react'
import EverythingDataPages from './EverythingDataPages'

// Fetch-driven (#4557): the Page is a pure gate; GET /api/everything_data_pages on mount.
const jsonFetch = (p) => jest.fn(() => Promise.resolve({ json: () => Promise.resolve(p) }))
afterEach(() => { delete global.fetch; jest.restoreAllMocks() })

describe('EverythingDataPages (fetch-driven #4557)', () => {
  it('fetches and renders both endpoint tables', async () => {
    global.fetch = jsonFetch({
      success: 1,
      fullpages: [{ node_id: 1, title: 'Some Fullpage' }],
      tickers: [{ node_id: 2, title: 'New Writeups XML Ticker' }]
    })
    const { container } = render(<EverythingDataPages />)
    await waitFor(() => expect(container.textContent).toMatch(/Some Fullpage/))
    expect(global.fetch.mock.calls[0][0]).toMatch(/^\/api\/everything_data_pages/)
    expect(container.textContent).toMatch(/New Writeups XML Ticker/)
  })

  it('renders empty states', async () => {
    global.fetch = jsonFetch({ success: 1, fullpages: [], tickers: [] })
    const { container } = render(<EverythingDataPages />)
    await waitFor(() => expect(container.textContent).toMatch(/No fullpage endpoints found/))
    expect(container.textContent).toMatch(/No ticker endpoints found/)
  })
})
