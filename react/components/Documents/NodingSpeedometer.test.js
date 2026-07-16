import React from 'react'
import { render, waitFor, fireEvent } from '@testing-library/react'
import NodingSpeedometer from './NodingSpeedometer'

// #4539: fetch-driven. GET /api/noding_speedometer (NoGuest); the speedometer colour/width/comment
// tiers are React config keyed on the raw `speed`. Form refetches in place via history.pushState.

const setLocation = (href) => {
  const u = new URL(href)
  window.location.href = href
  window.location.pathname = u.pathname
  window.location.search = u.search
}
const mockFetch = (payload) => jest.fn(() => Promise.resolve({ json: () => Promise.resolve(payload) }))

const fullResult = (overrides = {}) => ({
  success: 1, username: 'someuser', clock_nodes: 20, total_writeups: 100, actual_count: 20,
  days_elapsed: 40, speed: 2.0,
  level_data: { current_level: 5, next_level: 6, req_wu: 10, req_xp: 500, avg_xp: 12.5, nodes_needed: 10, days_to_level: 20 },
  ...overrides
})

beforeEach(() => setLocation('http://localhost/?node_id=200'))
afterEach(() => { delete global.fetch; jest.restoreAllMocks() })

describe('NodingSpeedometer — fetch + NoGuest (#4539)', () => {
  it('renders the guest message when the API refuses', async () => {
    global.fetch = mockFetch({ success: 0, state: 'guest' })
    const { container } = render(<NodingSpeedometer />)
    await waitFor(() => expect(container.textContent).toMatch(/only registered members/i))
  })

  it('shows the form shell prompt when no user is given', async () => {
    global.fetch = mockFetch({ success: 1, username: 'me', clock_nodes: 50 })
    const { container } = render(<NodingSpeedometer />)
    await waitFor(() => expect(container.textContent).toMatch(/who should we clock/i))
    expect(container.querySelector('input[name="speedyuser"]')).toBeTruthy()
  })

  it('renders results with a speedometer tier computed in React (color/width/comment)', async () => {
    setLocation('http://localhost/?node_id=200&speedyuser=someuser')
    global.fetch = mockFetch(fullResult({ speed: 2.0 })) // 2.0 -> orange/75%
    const { container } = render(<NodingSpeedometer />)
    await waitFor(() => expect(container.querySelector('.noding-speedometer__results')).toBeTruthy())
    expect(container.textContent).toMatch(/2\.00 days per node/)
    const bar = container.querySelector('.noding-speedometer__bar')
    expect(bar.style.width).toBe('75%')
    expect(bar.style.backgroundColor).toBe('orange')
    expect(container.querySelector('.noding-speedometer__comment').textContent).toMatch(/doughnut bribe/)
  })

  it('interpolates the username into the tier comment for fast speeds', async () => {
    setLocation('http://localhost/?node_id=200&speedyuser=speedy')
    global.fetch = mockFetch(fullResult({ username: 'speedy', speed: 0.5 })) // <=0.75 -> "broken the speedometer"
    const { container } = render(<NodingSpeedometer />)
    await waitFor(() => expect(container.querySelector('.noding-speedometer__comment')).toBeTruthy())
    expect(container.querySelector('.noding-speedometer__comment').textContent).toMatch(/speedy has broken the speedometer/)
  })

  it.each([
    ['user_not_found', "Your aim is way off. nobody isn't a user"],
    ['no_writeups', 'has no writeups'],
    ['insufficient_days', 'do at least one lap']
  ])('renders the %s message', async (state, copy) => {
    setLocation('http://localhost/?node_id=200&speedyuser=nobody')
    global.fetch = mockFetch({ success: 0, state, username: 'nobody' })
    const { container } = render(<NodingSpeedometer />)
    await waitFor(() => expect(container.textContent).toMatch(new RegExp(copy.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i')))
  })
})

describe('NodingSpeedometer — in-place submit (#4539, no reload)', () => {
  it('submits in place: refetches with speedyuser, pushes URL, no reload', async () => {
    const pushSpy = jest.spyOn(window.history, 'pushState').mockImplementation(() => {})
    global.fetch = mockFetch({ success: 1, username: 'me', clock_nodes: 50 })
    const { container } = render(<NodingSpeedometer />)
    await waitFor(() => expect(container.querySelector('.noding-speedometer__form')).toBeTruthy())

    fireEvent.change(container.querySelector('input[name="speedyuser"]'), { target: { value: 'racer' } })
    fireEvent.submit(container.querySelector('.noding-speedometer__form'))
    await waitFor(() => expect(global.fetch.mock.calls.length).toBe(2))

    expect(window.location.href).toBe('http://localhost/?node_id=200') // no hard navigation
    expect(global.fetch.mock.calls[1][0]).toContain('speedyuser=racer')
    expect(pushSpy.mock.calls[pushSpy.mock.calls.length - 1][2]).toContain('speedyuser=racer')
  })
})
