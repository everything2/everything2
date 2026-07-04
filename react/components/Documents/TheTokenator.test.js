import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import TheTokenator from './TheTokenator'
import fixture from '../../__fixtures__/pagestate/the_tokenator.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('TheTokenator (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<TheTokenator data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<TheTokenator data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// Interaction coverage (#4455): give-tokens moved to POST /api/the_tokenator/tokenate,
// so the component posts the usernames and renders per-user results from the response.
describe('TheTokenator interaction (#4455)', () => {
  afterEach(() => {
    jest.restoreAllMocks()
    delete global.fetch
  })

  it('posts the usernames to /api/the_tokenator/tokenate and renders results', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ success: 1, results: [{ success: 1, username: 'bob', message: 'User bob was given one token' }] }),
    })
    render(<TheTokenator data={{ type: 'the_tokenator' }} />)
    fireEvent.change(screen.getAllByRole('textbox')[0], { target: { value: 'bob' } })
    fireEvent.click(screen.getByRole('button', { name: /give tokens/i }))
    await waitFor(() =>
      expect(global.fetch).toHaveBeenCalledWith('/api/the_tokenator/tokenate', expect.objectContaining({ method: 'POST' }))
    )
    expect(JSON.parse(global.fetch.mock.calls[0][1].body)).toEqual({ users: ['bob'] })
    await waitFor(() => expect(screen.getByText(/User bob was given one token/)).toBeInTheDocument())
  })

  it('renders a per-user not-found error from the API', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ success: 1, results: [{ success: 0, username: 'bob', message: "Couldn't find user bob" }] }),
    })
    render(<TheTokenator data={{ type: 'the_tokenator' }} />)
    fireEvent.change(screen.getAllByRole('textbox')[0], { target: { value: 'bob' } })
    fireEvent.click(screen.getByRole('button', { name: /give tokens/i }))
    await waitFor(() => expect(screen.getByText(/Couldn't find user bob/)).toBeInTheDocument())
  })

  it('does not fetch when all rows are blank', () => {
    global.fetch = jest.fn()
    render(<TheTokenator data={{ type: 'the_tokenator' }} />)
    fireEvent.click(screen.getByRole('button', { name: /give tokens/i }))
    expect(global.fetch).not.toHaveBeenCalled()
  })

  it('renders the access-denied box with no form', () => {
    render(<TheTokenator data={{ type: 'the_tokenator', access_denied: 1 }} />)
    expect(screen.getByText(/Admins only/i)).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /give tokens/i })).toBeNull()
  })
})
