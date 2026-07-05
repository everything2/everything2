import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import E2Bouncer from './E2Bouncer'
import fixture from '../../__fixtures__/pagestate/e2_bouncer.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('E2Bouncer (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<E2Bouncer data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<E2Bouncer data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

describe('E2Bouncer chanop gating (user prop, #4390)', () => {
  it('renders the bouncer form for a chanop (user.chanop true)', () => {
    const { container } = render(<E2Bouncer data={fixture.contentData} e2={fixture} user={{ chanop: true }} />)
    expect(container.textContent).toContain('Nerf Borg')
    expect(container.textContent).not.toContain('Permission Denied')
  })
  it('shows Permission Denied for a non-chanop (user.chanop false)', () => {
    const { container } = render(<E2Bouncer data={fixture.contentData} e2={fixture} user={{ chanop: false }} />)
    expect(container.textContent).toContain('Permission Denied')
    expect(container.textContent).toContain('Channel Operators')
  })
  it('does not crash and denies access when user prop is undefined', () => {
    const { container } = render(<E2Bouncer data={fixture.contentData} e2={fixture} user={undefined} />)
    expect(container.textContent).toContain('Permission Denied')
  })
})

// Interaction coverage: the bulk room-move posts to /api/bouncer.
describe('E2Bouncer interaction', () => {
  const chanop = { chanop: true }
  const rooms = [{ node_id: 10, title: 'Political Asylum' }]
  const usersBox = () => screen.getByPlaceholderText(/username1/)
  const move = () => fireEvent.click(screen.getByRole('button', { name: /move users/i }))

  afterEach(() => {
    jest.restoreAllMocks()
    delete global.fetch
  })

  it('blocks an empty submit with an error and no network call', () => {
    global.fetch = jest.fn()
    render(<E2Bouncer data={{ rooms }} user={chanop} />)
    move()
    expect(screen.getByText(/enter at least one username/i)).toBeInTheDocument()
    expect(global.fetch).not.toHaveBeenCalled()
  })

  it('posts the parsed usernames + selected room and renders the moved list', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ success: true, room_title: 'Political Asylum', moved: ['alice'] }),
    })
    render(<E2Bouncer data={{ rooms }} user={chanop} />)
    fireEvent.change(usersBox(), { target: { value: 'alice\n\n' } })
    fireEvent.change(screen.getByRole('combobox'), { target: { value: 'Political Asylum' } })
    move()

    await waitFor(() => expect(global.fetch).toHaveBeenCalledWith('/api/bouncer', expect.objectContaining({ method: 'POST' })))
    const body = JSON.parse(global.fetch.mock.calls[0][1].body)
    expect(body).toEqual({ usernames: ['alice'], room_title: 'Political Asylum' })

    await waitFor(() => expect(screen.getByRole('link', { name: 'alice' })).toBeInTheDocument())
    // usernames cleared on success
    expect(usersBox()).toHaveValue('')
  })

  it('surfaces not-found users returned by the API', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ success: true, room_title: 'outside', moved: [], not_found: ['ghost'] }),
    })
    render(<E2Bouncer data={{ rooms }} user={chanop} />)
    fireEvent.change(usersBox(), { target: { value: 'ghost' } })
    move()
    await waitFor(() => expect(screen.getByText(/does not exist/i)).toBeInTheDocument())
    // the not-found entry names the missing user
    expect(screen.getByRole('heading', { name: /users not found/i })).toBeInTheDocument()
  })
})
