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
