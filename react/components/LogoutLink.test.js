import React from 'react'
import { render, screen, fireEvent } from '@testing-library/react'
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
  })

  afterEach(() => {
    window.location = originalLocation
  })

  it('renders with default "Log Out" text', () => {
    render(<LogoutLink />)
    expect(screen.getByText('Log Out')).toBeInTheDocument()
  })

  it('renders with custom display text', () => {
    render(<LogoutLink display="Sign Out" />)
    expect(screen.getByText('Sign Out')).toBeInTheDocument()
  })

  it('has correct href with op=logout', () => {
    render(<LogoutLink />)
    const link = screen.getByText('Log Out')
    expect(link).toHaveAttribute('href', '/node/superdoc/login?op=logout')
  })

  it('clears cookie client-side as backup on click', () => {
    // Set a test cookie first
    document.cookie = 'userpass=testvalue; path=/'

    render(<LogoutLink />)
    const link = screen.getByText('Log Out')

    fireEvent.click(link)

    // Check that cookie was cleared (expired) client-side
    // Note: In jsdom, checking cookie expiration is tricky, but we can verify
    // the cookie value is empty or the cookie is gone
    expect(document.cookie).not.toContain('userpass=testvalue')
  })

  it('allows default link navigation (does not preventDefault)', () => {
    render(<LogoutLink />)
    const link = screen.getByText('Log Out')

    const clickEvent = new MouseEvent('click', {
      bubbles: true,
      cancelable: true
    })

    link.dispatchEvent(clickEvent)

    // Should NOT prevent default - we want the navigation to happen
    expect(clickEvent.defaultPrevented).toBe(false)
  })
})
