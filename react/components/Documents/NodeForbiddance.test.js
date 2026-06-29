import React from 'react'
import { render, fireEvent, waitFor } from '@testing-library/react'
import NodeForbiddance from './NodeForbiddance'
import fixture from '../../__fixtures__/pagestate/node_forbiddance.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('NodeForbiddance (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<NodeForbiddance data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<NodeForbiddance data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// #4408: forbid/unforbid POST to /api/nodeforbiddance/* (were a POST form /
// GET link that mutated nodelock during render) and reload on success.
describe('NodeForbiddance — forbid/unforbid via API (#4408)', () => {
  const data = {
    forbidden_users: [
      { user_id: 7, user_title: 'victim', forbidder_id: 9, forbidder_title: 'forbidder', reason: '' },
    ],
  }

  const withReload = async (fn) => {
    const saved = window.location
    const reload = jest.fn()
    delete window.location
    window.location = { reload }
    try { await fn(reload) } finally { window.location = saved }
  }

  it('forbid form POSTs {user,reason} and reloads', async () => {
    await withReload(async (reload) => {
      const fetchMock = (global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: 1 }) }))
      try {
        const { getByPlaceholderText, getByRole } = render(<NodeForbiddance data={data} />)
        fireEvent.change(getByPlaceholderText('Username'), { target: { value: 'baduser' } })
        fireEvent.change(getByPlaceholderText('Reason for forbiddance'), { target: { value: 'spamming' } })
        fireEvent.click(getByRole('button', { name: /forbid user/i }))
        await waitFor(() =>
          expect(fetchMock).toHaveBeenCalledWith('/api/nodeforbiddance/forbid', expect.objectContaining({ method: 'POST' }))
        )
        expect(JSON.parse(fetchMock.mock.calls[0][1].body)).toEqual({ user: 'baduser', reason: 'spamming' })
        await waitFor(() => expect(reload).toHaveBeenCalled())
      } finally { delete global.fetch }
    })
  })

  it('unforbid button POSTs {user_id} and reloads', async () => {
    await withReload(async (reload) => {
      const fetchMock = (global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: 1 }) }))
      try {
        const { getByRole } = render(<NodeForbiddance data={data} />)
        fireEvent.click(getByRole('button', { name: /unforbid/i }))
        await waitFor(() =>
          expect(fetchMock).toHaveBeenCalledWith('/api/nodeforbiddance/unforbid', expect.objectContaining({ method: 'POST' }))
        )
        expect(JSON.parse(fetchMock.mock.calls[0][1].body)).toEqual({ user_id: 7 })
        await waitFor(() => expect(reload).toHaveBeenCalled())
      } finally { delete global.fetch }
    })
  })

  it('shows an error and does not reload when the API rejects', async () => {
    await withReload(async (reload) => {
      global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: 0, error: 'Admin access required' }) })
      try {
        const { getByPlaceholderText, getByRole, getByText } = render(<NodeForbiddance data={data} />)
        fireEvent.change(getByPlaceholderText('Username'), { target: { value: 'x' } })
        fireEvent.click(getByRole('button', { name: /forbid user/i }))
        await waitFor(() => expect(getByText(/admin access required/i)).toBeInTheDocument())
        expect(reload).not.toHaveBeenCalled()
      } finally { delete global.fetch }
    })
  })

  it('requires a username before forbidding (no fetch)', () => {
    global.fetch = jest.fn()
    try {
      const { getByRole, getByText } = render(<NodeForbiddance data={data} />)
      fireEvent.click(getByRole('button', { name: /forbid user/i }))
      expect(getByText(/enter a username/i)).toBeInTheDocument()
      expect(global.fetch).not.toHaveBeenCalled()
    } finally { delete global.fetch }
  })
})
