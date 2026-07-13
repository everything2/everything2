import React from 'react'
import { render, waitFor, fireEvent } from '@testing-library/react'
import IpHunter from './IpHunter'

// Fully client-resolved (#4530): the Page is a pure gate. IpHunter fetches GET /api/ip_hunter
// (admin-gated) on mount, reading hunt_name/hunt_ip off the URL. Search + "hunt" cross-links refetch
// IN PLACE (no reload), syncing the URL via history.pushState.

const setLocation = (href) => {
  const u = new URL(href)
  window.location.href = href
  window.location.pathname = u.pathname
  window.location.search = u.search
}
const mockFetch = (payload) => jest.fn(() => Promise.resolve({ json: () => Promise.resolve(payload) }))

beforeEach(() => setLocation('http://localhost/?node_id=1244409'))
afterEach(() => { delete global.fetch; jest.restoreAllMocks() })

describe('IpHunter — fetch + admin gate (#4530)', () => {
  it('renders the admin error when the API refuses', async () => {
    global.fetch = mockFetch({ success: 0, state: 'admin' })
    const { container } = render(<IpHunter />)
    await waitFor(() => expect(container.textContent).toMatch(/restricted to administrators/i))
  })

  it('shows the search form on the empty shell', async () => {
    global.fetch = mockFetch({ success: 1, result_limit: 500 })
    const { container } = render(<IpHunter />)
    await waitFor(() => expect(container.querySelector('.ip-hunter__form')).toBeTruthy())
    expect(global.fetch.mock.calls[0][0]).toMatch(/^\/api\/ip_hunter/)
    expect(container.textContent).toMatch(/enter an IP address or a name/i)
  })

  it('renders a user search (IPs the user logged in from), flagging banned IPs', async () => {
    setLocation('http://localhost/?node_id=1244409&hunt_name=root')
    global.fetch = mockFetch({
      success: 1, search_type: 'user', search_value: 'root', user_id: 113, user_title: 'root', result_limit: 500,
      results: [
        { ip: '10.0.0.1', time: '2020-01-01 00:00:00', banned: 0, banned_ranged: 0 },
        { ip: '10.0.0.2', time: '2020-01-02 00:00:00', banned: 1, banned_ranged: 0 }
      ]
    })
    const { container } = render(<IpHunter />)
    await waitFor(() => expect(container.querySelector('.ip-hunter__results-table')).toBeTruthy())
    expect(container.textContent).toMatch(/has been here as IPs/)
    expect(container.querySelector('strike')).toBeTruthy() // banned IP struck through
  })

  it('renders an IP search (users who logged in from an IP)', async () => {
    setLocation('http://localhost/?node_id=1244409&hunt_ip=10.0.0.1')
    global.fetch = mockFetch({
      success: 1, search_type: 'ip', search_value: '10.0.0.1', result_limit: 500,
      results: [{ user_id: 113, user_title: 'root', time: '2020-01-01 00:00:00' }]
    })
    const { container } = render(<IpHunter />)
    await waitFor(() => expect(container.textContent).toMatch(/has been here and logged on as/))
    expect(global.fetch.mock.calls[0][0]).toContain('hunt_ip=10.0.0.1')
  })

  it('renders the user_not_found copy from the state flag', async () => {
    setLocation('http://localhost/?node_id=1244409&hunt_name=nobodyzzz')
    global.fetch = mockFetch({ success: 0, state: 'user_not_found', search_value: 'nobodyzzz' })
    const { container } = render(<IpHunter />)
    await waitFor(() => expect(container.textContent).toMatch(/No such user: nobodyzzz/))
  })
})

describe('IpHunter — in-place search (#4530, no reload)', () => {
  it('submits the name search in place: refetches + pushes URL, no reload', async () => {
    const pushSpy = jest.spyOn(window.history, 'pushState').mockImplementation(() => {})
    global.fetch = mockFetch({ success: 1, result_limit: 500 })
    const { container } = render(<IpHunter />)
    await waitFor(() => expect(container.querySelector('.ip-hunter__form')).toBeTruthy())

    fireEvent.change(container.querySelector('input[name="hunt_name"]'), { target: { value: 'someuser' } })
    fireEvent.submit(container.querySelector('.ip-hunter__form'))
    await waitFor(() => expect(global.fetch.mock.calls.length).toBe(2))

    expect(window.location.href).toBe('http://localhost/?node_id=1244409') // no hard navigation
    expect(global.fetch.mock.calls[1][0]).toContain('hunt_name=someuser')
    expect(pushSpy.mock.calls[pushSpy.mock.calls.length - 1][2]).toContain('hunt_name=someuser')
  })

  it('a "hunt" cross-link on an IP row refetches that IP in place', async () => {
    setLocation('http://localhost/?node_id=1244409&hunt_name=root')
    const pushSpy = jest.spyOn(window.history, 'pushState').mockImplementation(() => {})
    global.fetch = mockFetch({
      success: 1, search_type: 'user', search_value: 'root', user_id: 113, user_title: 'root', result_limit: 500,
      results: [{ ip: '10.0.0.9', time: '2020-01-01 00:00:00', banned: 0, banned_ranged: 0 }]
    })
    const { container, getByText } = render(<IpHunter />)
    await waitFor(() => expect(container.querySelector('.ip-hunter__results-table')).toBeTruthy())

    fireEvent.click(getByText('10.0.0.9'))
    await waitFor(() => expect(global.fetch.mock.calls.length).toBe(2))
    expect(window.location.href).toBe('http://localhost/?node_id=1244409&hunt_name=root') // no reload
    expect(global.fetch.mock.calls[1][0]).toContain('hunt_ip=10.0.0.9')
    expect(pushSpy.mock.calls[pushSpy.mock.calls.length - 1][2]).toContain('hunt_ip=10.0.0.9')
  })
})
