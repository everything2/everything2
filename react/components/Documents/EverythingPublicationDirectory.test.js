import React from 'react'
import { render, waitFor, fireEvent } from '@testing-library/react'
import EverythingPublicationDirectory from './EverythingPublicationDirectory'

// Fetch-driven (#4557): the Page is a pure gate; the thepub||admin gate lives in
// GET /api/everything_publication_directory.
const jsonFetch = (p) => jest.fn(() => Promise.resolve({ json: () => Promise.resolve(p) }))
afterEach(() => { delete global.fetch; jest.restoreAllMocks() })

describe('EverythingPublicationDirectory (fetch-driven #4557)', () => {
  it('renders debates for a permitted member', async () => {
    global.fetch = jsonFetch({
      success: 1,
      debates: [{ node_id: 5, title: 'A Debate', author_id: 7, author_title: 'alice',
                  created: '1/2/2026', latest_time: '3/4/2026', restricted_id: 1797556, restricted_title: 'thepub' }]
    })
    const { container } = render(<EverythingPublicationDirectory />)
    await waitFor(() => expect(container.textContent).toMatch(/A Debate/))
    expect(global.fetch.mock.calls[0][0]).toMatch(/^\/api\/everything_publication_directory/)
    expect(container.textContent).toMatch(/alice/)
  })

  it('shows the restriction message on permission denied', async () => {
    global.fetch = jsonFetch({ success: 0, state: 'permission' })
    const { container } = render(<EverythingPublicationDirectory />)
    await waitFor(() => expect(container.textContent).toMatch(/restricted to thepub/i))
    expect(container.textContent).not.toMatch(/A Debate/)
  })

  it('shows the login message for guests', async () => {
    global.fetch = jsonFetch({ success: 0, state: 'guest' })
    const { container } = render(<EverythingPublicationDirectory />)
    await waitFor(() => expect(container.textContent).toMatch(/log in first/i))
  })

  // Debate creation still goes through the generic node API (#4340) — unchanged by #4557, kept covered.
  it('creates a debate via /api/node/create and redirects to /node/<id>', async () => {
    delete window.location
    window.location = { href: '' }
    global.fetch = jest.fn((url) =>
      Promise.resolve({
        ok: true,
        json: () => Promise.resolve(
          String(url).includes('/api/node/create')
            ? { success: 1, node_id: 777 }
            : { success: 1, debates: [] }
        )
      })
    )
    const { container } = render(<EverythingPublicationDirectory />)
    await waitFor(() => expect(container.querySelector('.e2-pub-directory__input')).toBeTruthy())

    fireEvent.change(container.querySelector('.e2-pub-directory__input'), { target: { value: 'New Debate' } })
    fireEvent.submit(container.querySelector('.e2-pub-directory__create-form form'))

    await waitFor(() => expect(window.location.href).toBe('/node/777'))
    const create = global.fetch.mock.calls.find((c) => String(c[0]).includes('/api/node/create'))
    expect(JSON.parse(create[1].body)).toEqual({ type: 'debate', title: 'New Debate' })
  })

  it('does not call the API when the title is empty', async () => {
    jest.spyOn(window, 'alert').mockImplementation(() => {})
    global.fetch = jsonFetch({ success: 1, debates: [] })
    const { container } = render(<EverythingPublicationDirectory />)
    await waitFor(() => expect(container.querySelector('.e2-pub-directory__input')).toBeTruthy())

    fireEvent.change(container.querySelector('.e2-pub-directory__input'), { target: { value: '  ' } })
    fireEvent.submit(container.querySelector('.e2-pub-directory__create-form form'))

    await waitFor(() => expect(window.alert).toHaveBeenCalled())
    expect(global.fetch.mock.calls.some((c) => String(c[0]).includes('/api/node/create'))).toBe(false)
  })
})
