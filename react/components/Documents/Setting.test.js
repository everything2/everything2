import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import Setting from './Setting'
import fixture from '../../__fixtures__/pagestate/setting.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// captured as an authenticated (root) request -- this is an auth-gated view.
describe('Setting (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<Setting data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<Setting data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// Interaction coverage: the setting-vars editor writes each key/value to
// /api/nodevars/:id/set (add + update) and /api/nodevars/:id/delete. Client-side key
// validation must gate the add before it hits the network.
describe('Setting editor interaction', () => {
  const editData = () => ({
    setting: { node_id: 500, vars: [{ key: 'foo', value: 'bar' }] },
    displaytype: 'edit', // start in edit mode
    user: { is_admin: true },
  })
  const keyInput = () => screen.getByPlaceholderText('Key')
  const valueInput = () => screen.getByPlaceholderText('Value')
  const addBtn = () => screen.getByRole('button', { name: /add/i })

  afterEach(() => {
    jest.restoreAllMocks()
    delete global.fetch
  })

  it('renders an error when the setting is missing', () => {
    render(<Setting data={{ setting: null }} />)
    expect(screen.getByText(/setting not found/i)).toBeInTheDocument()
  })

  it('rejects an empty key and an invalid key format without calling the API', () => {
    global.fetch = jest.fn()
    render(<Setting data={editData()} />)

    fireEvent.click(addBtn())
    expect(screen.getByText(/key is required/i)).toBeInTheDocument()

    fireEvent.change(keyInput(), { target: { value: 'has spaces!' } })
    fireEvent.click(addBtn())
    expect(screen.getByText(/invalid key format/i)).toBeInTheDocument()
    expect(global.fetch).not.toHaveBeenCalled()
  })

  it('rejects a duplicate key without calling the API', () => {
    global.fetch = jest.fn()
    render(<Setting data={editData()} />)
    fireEvent.change(keyInput(), { target: { value: 'foo' } }) // already exists
    fireEvent.click(addBtn())
    expect(screen.getByText(/key already exists/i)).toBeInTheDocument()
    expect(global.fetch).not.toHaveBeenCalled()
  })

  it('adds a valid var via POST /api/nodevars/:id/set and shows it in the table', async () => {
    global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: true }) })
    render(<Setting data={editData()} />)
    fireEvent.change(keyInput(), { target: { value: 'newkey' } })
    fireEvent.change(valueInput(), { target: { value: 'newval' } })
    fireEvent.click(addBtn())

    await waitFor(() =>
      expect(global.fetch).toHaveBeenCalledWith('/api/nodevars/500/set', expect.objectContaining({ method: 'POST' }))
    )
    expect(JSON.parse(global.fetch.mock.calls[0][1].body)).toEqual({ key: 'newkey', value: 'newval' })
    await waitFor(() => expect(screen.getByText('newkey')).toBeInTheDocument())
  })

  it('deletes a var (after confirm) via POST /api/nodevars/:id/delete', async () => {
    jest.spyOn(window, 'confirm').mockReturnValue(true)
    global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: true }) })
    render(<Setting data={editData()} />)
    fireEvent.click(screen.getByRole('button', { name: 'Delete' }))

    await waitFor(() =>
      expect(global.fetch).toHaveBeenCalledWith('/api/nodevars/500/delete', expect.objectContaining({ method: 'POST' }))
    )
    expect(JSON.parse(global.fetch.mock.calls[0][1].body)).toEqual({ key: 'foo' })
    // row gone
    await waitFor(() => expect(screen.queryByText('foo')).toBeNull())
  })
})
