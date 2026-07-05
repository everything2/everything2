import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import NatesSecretUnborgDoc from './NatesSecretUnborgDoc'
import fixture from '../../__fixtures__/pagestate/nate_s_secret_unborg_doc.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('NatesSecretUnborgDoc (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<NatesSecretUnborgDoc data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<NatesSecretUnborgDoc data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// Interaction coverage (#4468): unborg moved to POST /api/nate_s_secret_unborg_doc/unborg,
// and on success the page reloads so the chrome (chat) re-enables.
describe('NatesSecretUnborgDoc interaction (#4468)', () => {
  let reloadMock
  beforeEach(() => {
    reloadMock = jest.fn()
    Object.defineProperty(window, 'location', { configurable: true, value: { reload: reloadMock } })
  })
  afterEach(() => {
    jest.restoreAllMocks()
    delete global.fetch
  })

  it('shows the button for an admin', () => {
    render(<NatesSecretUnborgDoc data={{ type: 'nate_s_secret_unborg_doc', is_admin: 1 }} />)
    expect(screen.getByRole('button', { name: /unborg me/i })).toBeInTheDocument()
  })

  it('shows the brush-off (no button) for a non-admin', () => {
    render(<NatesSecretUnborgDoc data={{ type: 'nate_s_secret_unborg_doc', is_admin: 0, message: "Maybe you'd better just stay in there" }} />)
    expect(screen.getByText(/stay in there/i)).toBeInTheDocument()
    expect(screen.queryByRole('button')).toBeNull()
  })

  it('POSTs the unborg and reloads on success', async () => {
    global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: 1, message: "you're unborged" }) })
    render(<NatesSecretUnborgDoc data={{ type: 'nate_s_secret_unborg_doc', is_admin: 1 }} />)
    fireEvent.click(screen.getByRole('button', { name: /unborg me/i }))
    await waitFor(() =>
      expect(global.fetch).toHaveBeenCalledWith('/api/nate_s_secret_unborg_doc/unborg', expect.objectContaining({ method: 'POST' }))
    )
    await waitFor(() => expect(reloadMock).toHaveBeenCalled())
  })

  it('shows a message and does NOT reload on failure', async () => {
    global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: 0, message: 'nope' }) })
    render(<NatesSecretUnborgDoc data={{ type: 'nate_s_secret_unborg_doc', is_admin: 1 }} />)
    fireEvent.click(screen.getByRole('button', { name: /unborg me/i }))
    await waitFor(() => expect(screen.getByText(/nope/)).toBeInTheDocument())
    expect(reloadMock).not.toHaveBeenCalled()
  })
})
