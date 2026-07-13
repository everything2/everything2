import React from 'react'
import { render, waitFor, fireEvent } from '@testing-library/react'
import WhoKilledWhat from './WhoKilledWhat'

// Fully client-resolved (#4530): the Page is a pure gate. WhoKilledWhat fetches GET
// /api/who_killed_what (admin-gated) on mount, reading heavenuser/offset/limit off the URL. The
// search form refetches IN PLACE (no reload), syncing the URL via history.pushState. The
// offset/limit dropdown options are static React config, not shipped by the API.

const setLocation = (href) => {
  const u = new URL(href)
  window.location.href = href
  window.location.pathname = u.pathname
  window.location.search = u.search
}
const mockFetch = (payload) => jest.fn(() => Promise.resolve({ json: () => Promise.resolve(payload) }))

beforeEach(() => { setLocation('http://localhost/?node_id=794900'); window.e2 = { node_id: 794900 } })
afterEach(() => { delete global.fetch; delete window.e2; jest.restoreAllMocks() })

describe('WhoKilledWhat — fetch + admin gate (#4530)', () => {
  it('renders the admin error when the API refuses', async () => {
    global.fetch = mockFetch({ success: 0, state: 'admin' })
    const { container } = render(<WhoKilledWhat />)
    await waitFor(() => expect(container.textContent).toMatch(/restricted to administrators/i))
  })

  it('renders the kills table + summary for a target user', async () => {
    setLocation('http://localhost/?node_id=794900&heavenuser=root')
    global.fetch = mockFetch({
      success: 1, target_user: 'root', target_user_id: 113, total_kills: 2, offset: 0, limit: 100, node_heaven_id: 555,
      kills: [
        { node_id: 10, title: 'Bad Writeup', author_id: 7, author: 'someone', reputation: -5, createtime: '2020-01-01' },
        { node_id: 11, title: 'Worse Writeup', author_id: 0, author: 'Unknown', reputation: -9, createtime: '2020-01-02' }
      ]
    })
    const { container } = render(<WhoKilledWhat />)
    await waitFor(() => expect(container.querySelector('.who-killed__table')).toBeTruthy())
    expect(container.textContent).toMatch(/Kill count for root: 2/)
    expect(container.textContent).toMatch(/Bad Writeup/)
    // node_heaven link built from node_heaven_id
    expect(container.querySelector('a[href="?node_id=555&visit_id=10"]')).toBeTruthy()
  })

  it('renders the static offset/limit dropdown options (React config)', async () => {
    global.fetch = mockFetch({ success: 1, target_user: 'me', target_user_id: 1, total_kills: 0, kills: [], offset: 0, limit: 100 })
    const { container } = render(<WhoKilledWhat />)
    await waitFor(() => expect(container.querySelector('select[name="offset"]')).toBeTruthy())
    expect(container.querySelectorAll('select[name="offset"] option').length).toBe(26) // 0..5000 by 200
    expect(container.querySelectorAll('select[name="limit"] option').length).toBe(10)  // 50..500 by 50
  })

  it('renders the user_not_found copy from the state flag', async () => {
    setLocation('http://localhost/?node_id=794900&heavenuser=nobodyzzz')
    global.fetch = mockFetch({ success: 0, state: 'user_not_found', heavenuser: 'nobodyzzz' })
    const { container } = render(<WhoKilledWhat />)
    await waitFor(() => expect(container.textContent).toMatch(/User not found: nobodyzzz/))
  })
})

describe('WhoKilledWhat — in-place search (#4530, no reload)', () => {
  it('submits the search in place: refetches with the typed user, pushes URL, no reload', async () => {
    const pushSpy = jest.spyOn(window.history, 'pushState').mockImplementation(() => {})
    global.fetch = mockFetch({ success: 1, target_user: 'me', target_user_id: 1, total_kills: 0, kills: [], offset: 0, limit: 100 })
    const { container } = render(<WhoKilledWhat />)
    await waitFor(() => expect(container.querySelector('.who-killed__form')).toBeTruthy())

    fireEvent.change(container.querySelector('input[name="heavenuser"]'), { target: { value: 'someadmin' } })
    fireEvent.submit(container.querySelector('.who-killed__form'))
    await waitFor(() => expect(global.fetch.mock.calls.length).toBe(2))

    expect(window.location.href).toBe('http://localhost/?node_id=794900') // no hard navigation
    expect(global.fetch.mock.calls[1][0]).toContain('heavenuser=someadmin')
    expect(pushSpy.mock.calls[pushSpy.mock.calls.length - 1][2]).toContain('heavenuser=someadmin')
  })
})
