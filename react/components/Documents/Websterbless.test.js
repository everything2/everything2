import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import Websterbless from './Websterbless'
import fixture from '../../__fixtures__/pagestate/websterbless.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('Websterbless (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<Websterbless data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<Websterbless data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// Interaction coverage (#4451): the bless write moved to POST /api/websterbless/bless,
// so the component posts the blessings and renders the per-user results from the
// response (was a server-rendered POST-back).
describe('Websterbless interaction (#4451)', () => {
  const origLocation = window.location
  afterEach(() => {
    jest.restoreAllMocks()
    delete global.fetch
    Object.defineProperty(window, 'location', { configurable: true, writable: true, value: origLocation })
  })

  const setSearch = (search) =>
    Object.defineProperty(window, 'location', { configurable: true, writable: true, value: { search } })

  const authData = { type: 'websterbless', msg_count: 0, webster_id: 176726 }

  it('posts blessings to /api/websterbless/bless and renders results', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ success: 1, results: [{ success: 1, message: 'User bob was given 3 GP' }] }),
    })
    render(<Websterbless data={authData} />)
    fireEvent.change(screen.getAllByRole('textbox')[0], { target: { value: 'bob' } })
    fireEvent.click(screen.getByRole('button', { name: /websterbless/i }))
    await waitFor(() =>
      expect(global.fetch).toHaveBeenCalledWith('/api/websterbless/bless', expect.objectContaining({ method: 'POST' }))
    )
    await waitFor(() => expect(screen.getByText(/User bob was given 3 GP/)).toBeInTheDocument())
  })

  it('renders a per-user error from the API', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ success: 1, results: [{ success: 0, error: "Couldn't find user: bob" }] }),
    })
    render(<Websterbless data={authData} />)
    fireEvent.change(screen.getAllByRole('textbox')[0], { target: { value: 'bob' } })
    fireEvent.click(screen.getByRole('button', { name: /websterbless/i }))
    await waitFor(() => expect(screen.getByText(/Couldn't find user: bob/)).toBeInTheDocument())
  })

  // Permission denial no longer flows through this component (the Page returns { type:'staff_only' }
  // → StaffOnly, #4497). Websterbless still renders a *data* error inline — e.g. Webster 1913 missing.
  it('renders a data error (Webster 1913 missing) inline', () => {
    render(<Websterbless data={{ type: 'websterbless', error: 'Webster 1913 user not found in database.' }} />)
    expect(screen.getByText(/Webster 1913 user not found/i)).toBeInTheDocument()
  })

  // Prefill is client-owned (#4497): read off window.location, NOT shipped by the server.
  it('prefills the first username from the ?prefill_username URL hint', () => {
    setSearch('?prefill_username=webby')
    const { container } = render(<Websterbless data={authData} />)
    expect(container.querySelector('[name="webbyblessUser0"]').value).toBe('webby') // first row prefilled
    expect(container.querySelector('[name="webbyblessUser1"]').value).toBe('')      // second row blank
  })

  it('leaves the username blank when there is no prefill_username in the URL', () => {
    setSearch('')
    const { container } = render(<Websterbless data={authData} />)
    expect(container.querySelector('[name="webbyblessUser0"]').value).toBe('')
  })
})
