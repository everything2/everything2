import React from 'react'
import { render, waitFor, fireEvent } from '@testing-library/react'
import TheRegistries from './TheRegistries'

// Fetch-driven (#4548): GET /api/the_registries on mount; the include-empty toggle refetches in
// place with the param + history.pushState (no full-page reload). Login-required -> state:'guest'.
const setLocation = (href) => {
  const u = new URL(href)
  window.location.href = href
  window.location.pathname = u.pathname
  window.location.search = u.search
}
const jsonFetch = (p) => jest.fn(() => Promise.resolve({ json: () => Promise.resolve(p) }))

beforeEach(() => setLocation('http://localhost/?node_id=700'))
afterEach(() => { delete global.fetch; jest.restoreAllMocks() })

describe('TheRegistries (fetch-driven #4548)', () => {
  it('fetches /api/the_registries and renders the list', async () => {
    global.fetch = jsonFetch({ success: 1, count: 1, include_empty: false, registries: [{ node_id: 5, title: 'Noders by Location', entry_count: 3 }] })
    const { container } = render(<TheRegistries />)
    await waitFor(() => expect(container.textContent).toMatch(/Noders by Location/))
    expect(global.fetch.mock.calls[0][0]).toMatch(/^\/api\/the_registries/)
  })

  it('shows the guest message on state:guest', async () => {
    global.fetch = jsonFetch({ success: 0, state: 'guest' })
    const { container } = render(<TheRegistries />)
    await waitFor(() => expect(container.textContent).toMatch(/better log in/i))
  })

  it('toggles include-empty in place: refetches with the param, pushes URL, no reload', async () => {
    const pushSpy = jest.spyOn(window.history, 'pushState').mockImplementation(() => {})
    global.fetch = jsonFetch({ success: 1, count: 1, include_empty: false, registries: [{ node_id: 5, title: 'R', entry_count: 1 }] })
    const { container } = render(<TheRegistries />)
    await waitFor(() => expect(container.querySelector('.the-registries__toggle-input')).toBeTruthy())

    fireEvent.click(container.querySelector('.the-registries__toggle-input'))
    await waitFor(() => expect(global.fetch.mock.calls.length).toBe(2))
    expect(window.location.href).toBe('http://localhost/?node_id=700') // no reload
    expect(global.fetch.mock.calls[1][0]).toContain('include_empty=1')
    expect(pushSpy.mock.calls[pushSpy.mock.calls.length - 1][2]).toContain('include_empty=1')
  })
})
