import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import LogoutLink from './LogoutLink'

describe('LogoutLink Component', () => {
  let originalLocation

  beforeEach(() => {
    // Mock window.location
    originalLocation = window.location
    delete window.location
    window.location = { href: '' }

    // Clear cookies
    document.cookie = 'userpass=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;'

    // Mock the sessions API
    global.fetch = jest.fn(() => Promise.resolve({ ok: true, json: async () => ({}) }))
  })

  afterEach(() => {
    window.location = originalLocation
    jest.restoreAllMocks()
  })

  it('renders with default "Log Out" text', () => {
    render(<LogoutLink />)
    expect(screen.getByText('Log Out')).toBeInTheDocument()
  })

  it('renders with custom display text', () => {
    render(<LogoutLink display="Sign Out" />)
    expect(screen.getByText('Sign Out')).toBeInTheDocument()
  })

  it('POSTs to /api/sessions/delete on click, then redirects home', async () => {
    render(<LogoutLink />)
    const link = screen.getByText('Log Out')

    fireEvent.click(link)

    await waitFor(() => {
      expect(global.fetch).toHaveBeenCalledWith(
        '/api/sessions/delete',
        expect.objectContaining({ method: 'POST', credentials: 'same-origin' })
      )
    })
    await waitFor(() => {
      expect(window.location.href).toBe('/')
    })
  })

  it('clears cookie client-side as backup on click', async () => {
    // Set a test cookie first
    document.cookie = 'userpass=testvalue; path=/'

    render(<LogoutLink />)
    const link = screen.getByText('Log Out')

    fireEvent.click(link)

    await waitFor(() => {
      expect(document.cookie).not.toContain('userpass=testvalue')
    })
  })

  it('prevents default navigation (logout is handled via the API)', () => {
    render(<LogoutLink />)
    const link = screen.getByText('Log Out')

    const clickEvent = new MouseEvent('click', { bubbles: true, cancelable: true })
    link.dispatchEvent(clickEvent)

    // The handler calls preventDefault() and logs out via fetch instead
    expect(clickEvent.defaultPrevented).toBe(true)
  })
})
