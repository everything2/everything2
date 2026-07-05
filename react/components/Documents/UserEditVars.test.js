import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import UserEditVars from './UserEditVars'
import fixture from '../../__fixtures__/pagestate/user_editvars.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// captured as an authenticated (root) request -- this is an auth-gated view.
describe('UserEditVars (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<UserEditVars data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<UserEditVars data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// Interaction coverage: the user-vars editor is the same nodevars CRUD as Setting, targeting a
// user node. Cover the full add/update/delete round-trip against /api/nodevars/:id/set|delete.
describe('UserEditVars CRUD interaction', () => {
  const editData = () => ({
    target_user: { node_id: 700, title: 'someuser' },
    vars: [{ key: 'alpha', value: '1' }],
    viewer: { is_admin: true },
  })

  afterEach(() => {
    jest.restoreAllMocks()
    delete global.fetch
  })

  it('renders an error when the target user is missing', () => {
    render(<UserEditVars data={{ target_user: null }} />)
    expect(screen.getByText(/user not found/i)).toBeInTheDocument()
  })

  it('adds a var via POST /api/nodevars/:id/set', async () => {
    global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: true }) })
    render(<UserEditVars data={editData()} />)
    fireEvent.change(screen.getByPlaceholderText('Key'), { target: { value: 'beta' } })
    fireEvent.change(screen.getByPlaceholderText('Value'), { target: { value: '2' } })
    fireEvent.click(screen.getByRole('button', { name: /add/i }))

    await waitFor(() =>
      expect(global.fetch).toHaveBeenCalledWith('/api/nodevars/700/set', expect.objectContaining({ method: 'POST' }))
    )
    expect(JSON.parse(global.fetch.mock.calls[0][1].body)).toEqual({ key: 'beta', value: '2' })
    await waitFor(() => expect(screen.getByText('beta')).toBeInTheDocument())
  })

  it('updates an existing var value via POST /api/nodevars/:id/set', async () => {
    global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: true }) })
    render(<UserEditVars data={editData()} />)
    fireEvent.click(screen.getByRole('button', { name: 'Edit' }))
    // the value cell becomes a textarea prefilled with the current value
    fireEvent.change(screen.getByDisplayValue('1'), { target: { value: '99' } })
    fireEvent.click(screen.getByRole('button', { name: 'Save' }))

    await waitFor(() =>
      expect(global.fetch).toHaveBeenCalledWith('/api/nodevars/700/set', expect.objectContaining({ method: 'POST' }))
    )
    expect(JSON.parse(global.fetch.mock.calls[0][1].body)).toEqual({ key: 'alpha', value: '99' })
  })

  it('deletes a var (after confirm) via POST /api/nodevars/:id/delete', async () => {
    jest.spyOn(window, 'confirm').mockReturnValue(true)
    global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: true }) })
    render(<UserEditVars data={editData()} />)
    fireEvent.click(screen.getByRole('button', { name: 'Delete' }))

    await waitFor(() =>
      expect(global.fetch).toHaveBeenCalledWith('/api/nodevars/700/delete', expect.objectContaining({ method: 'POST' }))
    )
    expect(JSON.parse(global.fetch.mock.calls[0][1].body)).toEqual({ key: 'alpha' })
    await waitFor(() => expect(screen.queryByText('alpha')).toBeNull())
  })
})
