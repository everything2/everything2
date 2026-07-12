import React from 'react'
import { render, fireEvent, waitFor } from '@testing-library/react'
import ConfirmPassword from './ConfirmPassword'
import fixture from '../../__fixtures__/pagestate/confirm_password.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('ConfirmPassword (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<ConfirmPassword data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<ConfirmPassword data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// #4511: the server (Page + API) ships only { state } (+ backend links); React owns the copy.
describe('ConfirmPassword state copy (owned by React)', () => {
  it('login_required: derives the prompt from action, with no server-shipped copy', () => {
    const { container } = render(<ConfirmPassword data={{ state: 'login_required', username: 'alice', action: 'activate' }} />)
    expect(container.textContent).toMatch(/Please log in with your username and password to activate your account/)
    expect(container.querySelector('form')).toBeTruthy()
  })

  it('missing_params: renders the email guidance', () => {
    const { container } = render(<ConfirmPassword data={{ state: 'missing_params' }} />)
    expect(container.textContent).toMatch(/click on or copy and paste the link from the email/i)
  })

  it('invalid_action: renders the invalid-action copy', () => {
    const { container } = render(<ConfirmPassword data={{ state: 'invalid_action' }} />)
    expect(container.textContent).toMatch(/Invalid action\./)
  })

  it('expired: renders the expired copy plus the backend-supplied renew link', () => {
    const { container } = render(<ConfirmPassword data={{ state: 'expired', renewLink: '/node/5' }} />)
    expect(container.textContent).toMatch(/This link has expired/)
    const a = container.querySelector('a[href="/node/5"]')
    expect(a).toBeTruthy()
    expect(a.textContent).toBe('get a new one')
  })

  it('no_user: renders the no-account copy plus the backend-supplied signup link', () => {
    const { container } = render(<ConfirmPassword data={{ state: 'no_user', signupLink: '/node/9' }} />)
    expect(container.textContent).toMatch(/account you are trying to activate does not exist/i)
    expect(container.querySelector('a[href="/node/9"]')).toBeTruthy()
  })

  it('locked: renders the IP-lock copy', () => {
    const { container } = render(<ConfirmPassword data={{ state: 'locked' }} />)
    expect(container.textContent).toMatch(/don't accept new users from the IP address/i)
  })
})

// op=login retired -> POST /api/users/confirm (#4335 Phase 3)
describe('ConfirmPassword confirm flow (/api/users/confirm)', () => {
  const baseData = {
    state: 'login_required', username: 'alice', action: 'activate',
    token: 'tok123', expiry: '1799999999', prompt: 'Please log in',
  }

  let originalLocation
  beforeEach(() => {
    originalLocation = window.location
    delete window.location
    window.location = { href: '' }
  })
  afterEach(() => {
    window.location = originalLocation
    jest.restoreAllMocks()
  })

  it('submits to /api/users/confirm and redirects into the logged-in page on success', async () => {
    global.fetch = jest.fn(() => Promise.resolve({
      ok: true, json: async () => ({
        success: 1, state: 'success_activate',
        message: 'Your account has been activated and you have been logged in.',
        profileUrl: '/node/42',
      }),
    }))
    const { container } = render(<ConfirmPassword data={baseData} />)
    const pw = container.querySelector('input[type="password"]')
    fireEvent.change(pw, { target: { value: 'hunter2' } })
    fireEvent.submit(pw.closest('form'))

    await waitFor(() => expect(global.fetch).toHaveBeenCalled())
    const [url, opts] = global.fetch.mock.calls[0]
    expect(url).toBe('/api/users/confirm')
    expect(JSON.parse(opts.body)).toEqual({
      username: 'alice', passwd: 'hunter2', token: 'tok123',
      action: 'activate', expiry: '1799999999',
    })
    // Redirects to the profile (logged-in chrome), not a manual refresh
    await waitFor(() => expect(window.location.href).toBe('/node/42'))
  })

  it('does not call the API with an empty password', () => {
    global.fetch = jest.fn()
    const { container } = render(<ConfirmPassword data={baseData} />)
    fireEvent.submit(container.querySelector('form'))
    expect(global.fetch).not.toHaveBeenCalled()
  })

  it('renders the error when confirm fails', async () => {
    global.fetch = jest.fn(() => Promise.resolve({
      ok: true, json: async () => ({
        success: 0, state: 'login_required',
        error: 'Password or link invalid. Please try again.',
      }),
    }))
    const { container, getByText } = render(<ConfirmPassword data={baseData} />)
    const pw = container.querySelector('input[type="password"]')
    fireEvent.change(pw, { target: { value: 'wrong' } })
    fireEvent.submit(pw.closest('form'))
    await waitFor(() => getByText(/link invalid/i))
  })

  it('includes expires when "stay logged in" is checked', async () => {
    global.fetch = jest.fn(() => Promise.resolve({
      ok: true, json: async () => ({ success: 1, state: 'success_reset', message: 'done' }),
    }))
    const { container } = render(<ConfirmPassword data={{ ...baseData, action: 'reset' }} />)
    fireEvent.change(container.querySelector('input[type="password"]'), { target: { value: 'newpw' } })
    fireEvent.click(container.querySelector('input[type="checkbox"]'))
    fireEvent.submit(container.querySelector('form'))
    await waitFor(() => expect(global.fetch).toHaveBeenCalled())
    expect(JSON.parse(global.fetch.mock.calls[0][1].body).expires).toBe('+10y')
  })
})
