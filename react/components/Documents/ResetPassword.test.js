import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import ResetPassword from './ResetPassword'
import fixture from '../../__fixtures__/pagestate/reset_password.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('ResetPassword (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<ResetPassword data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<ResetPassword data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// Interaction coverage: the reset request posts to /api/password/reset-request.
// The component enforces client-side validation before it ever hits the network.
describe('ResetPassword interaction', () => {
  afterEach(() => {
    jest.restoreAllMocks()
    delete global.fetch
  })

  function fill({ who, password, confirm }) {
    if (who !== undefined) fireEvent.change(screen.getByLabelText(/username or email/i), { target: { value: who } })
    if (password !== undefined) fireEvent.change(screen.getByLabelText(/^new password/i), { target: { value: password } })
    if (confirm !== undefined) fireEvent.change(screen.getByLabelText(/repeat new password/i), { target: { value: confirm } })
  }
  const submit = () => fireEvent.click(screen.getByRole('button', { name: /submit/i }))

  it('rejects mismatched passwords client-side without hitting the network', () => {
    global.fetch = jest.fn()
    render(<ResetPassword data={{}} />)
    fill({ who: 'alice', password: 'longenough', confirm: 'different' })
    submit()
    expect(screen.getByText(/passwords don't match/i)).toBeInTheDocument()
    expect(global.fetch).not.toHaveBeenCalled()
  })

  it('rejects a too-short password client-side', () => {
    global.fetch = jest.fn()
    render(<ResetPassword data={{}} />)
    fill({ who: 'alice', password: 'short', confirm: 'short' })
    submit()
    expect(screen.getByText(/at least 6 characters/i)).toBeInTheDocument()
    expect(global.fetch).not.toHaveBeenCalled()
  })

  it('posts a valid request to /api/password/reset-request and shows the success note', async () => {
    global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: 1, message: 'Reset email queued' }) })
    render(<ResetPassword data={{}} />)
    fill({ who: 'alice', password: 'longenough', confirm: 'longenough' })
    submit()
    await waitFor(() => expect(global.fetch).toHaveBeenCalledWith('/api/password/reset-request', expect.objectContaining({ method: 'POST' })))
    const body = JSON.parse(global.fetch.mock.calls[0][1].body)
    expect(body).toMatchObject({ who: 'alice', password: 'longenough', passwordConfirm: 'longenough' })
    await waitFor(() => expect(screen.getByText('Reset email queued')).toBeInTheDocument())
    expect(screen.getByText(/check your email/i)).toBeInTheDocument()
  })

  it('surfaces a server-side error from the API', async () => {
    global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: 0, error: 'No such user' }) })
    render(<ResetPassword data={{}} />)
    fill({ who: 'nobody', password: 'longenough', confirm: 'longenough' })
    submit()
    await waitFor(() => expect(screen.getByText('No such user')).toBeInTheDocument())
  })
})
