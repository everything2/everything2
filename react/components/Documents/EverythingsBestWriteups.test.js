import React from 'react'
import { render, waitFor } from '@testing-library/react'
import EverythingsBestWriteups from './EverythingsBestWriteups'

// Fetch-driven (#4546): the Page is a pure gate; the editor gate lives in
// GET /api/everything_s_best_writeups (the real boundary). Non-editors get success:0/state:'permission'.
const jsonFetch = (p) => jest.fn(() => Promise.resolve({ json: () => Promise.resolve(p) }))

describe('EverythingsBestWriteups (fetch-driven #4546)', () => {
  afterEach(() => { delete global.fetch; jest.restoreAllMocks() })

  it('renders the writeups for an editor', async () => {
    global.fetch = jsonFetch({
      success: 1,
      writeups: [{ writeup_id: 1, writeup_title: 'A WU', parent_id: 2, parent_title: 'A node', author_id: 3, author_title: 'alice', cooled: 9 }]
    })
    const { container } = render(<EverythingsBestWriteups />)
    await waitFor(() => expect(container.textContent).toMatch(/Most Cooled/))
    expect(global.fetch.mock.calls[0][0]).toMatch(/^\/api\/everything_s_best_writeups/)
    expect(container.textContent).toMatch(/A WU/)
    expect(container.textContent).toMatch(/9C!/)
  })

  it('shows a staff-only message on permission denied', async () => {
    global.fetch = jsonFetch({ success: 0, state: 'permission' })
    const { container } = render(<EverythingsBestWriteups />)
    await waitFor(() => expect(container.textContent).toMatch(/visible only to staff members/i))
    expect(container.textContent).not.toMatch(/Most Cooled/)
  })
})
