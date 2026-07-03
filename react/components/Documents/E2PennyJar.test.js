import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import E2PennyJar from './E2PennyJar'
import fixture from '../../__fixtures__/pagestate/e2_penny_jar.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('E2PennyJar (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<E2PennyJar data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<E2PennyJar data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// Interaction coverage (#4453): give/take moved to POST /api/e2_penny_jar/give|take,
// so the component fetches and updates the count/GP/message in place -- no more
// throwaway-form full-page POST.
describe('E2PennyJar interaction (#4453)', () => {
  afterEach(() => {
    jest.restoreAllMocks()
    delete global.fetch
  })

  const active = { type: 'e2_penny_jar', user_gp: 5, pennies_in_jar: 3, can_interact: 1 }

  it('give posts to /give and updates jar count + GP in place', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ success: 1, message: 'You gave a penny to the jar!', pennies_in_jar: 4, user_gp: 4 }),
    })
    render(<E2PennyJar data={active} />)
    fireEvent.click(screen.getByRole('button', { name: /give!/i }))
    await waitFor(() =>
      expect(global.fetch).toHaveBeenCalledWith('/api/e2_penny_jar/give', expect.objectContaining({ method: 'POST' }))
    )
    await waitFor(() => expect(screen.getByText(/You gave a penny to the jar!/)).toBeInTheDocument())
    expect(screen.getByText(/currently 4 pennies/)).toBeInTheDocument()
    expect(screen.getByText(/4 GP/)).toBeInTheDocument()
  })

  it('take posts to /take and updates jar count + GP in place', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ success: 1, message: 'You took a penny from the jar!', pennies_in_jar: 2, user_gp: 6 }),
    })
    render(<E2PennyJar data={active} />)
    fireEvent.click(screen.getByRole('button', { name: /take!/i }))
    await waitFor(() =>
      expect(global.fetch).toHaveBeenCalledWith('/api/e2_penny_jar/take', expect.objectContaining({ method: 'POST' }))
    )
    await waitFor(() => expect(screen.getByText(/You took a penny from the jar!/)).toBeInTheDocument())
    expect(screen.getByText(/currently 2 pennies/)).toBeInTheDocument()
  })

  it('renders a soft guard message from the API without breaking state', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ success: 0, message: 'Sorry, you do not have any GP to give!', pennies_in_jar: 3, user_gp: 0 }),
    })
    render(<E2PennyJar data={active} />)
    fireEvent.click(screen.getByRole('button', { name: /give!/i }))
    await waitFor(() => expect(screen.getByText(/do not have any GP to give/i)).toBeInTheDocument())
  })

  it('disables the give button when the user has no GP', () => {
    render(<E2PennyJar data={{ type: 'e2_penny_jar', user_gp: 0, pennies_in_jar: 3, can_interact: 1 }} />)
    expect(screen.getByRole('button', { name: /give!/i })).toBeDisabled()
  })

  it('shows the donate prompt (no buttons) when the jar is empty', () => {
    render(<E2PennyJar data={{ type: 'e2_penny_jar', user_gp: 5, pennies_in_jar: 0, can_interact: 1 }} />)
    expect(screen.getByText(/donate one/i)).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /give!/i })).toBeNull()
  })

  it('renders a hard error banner (guest/opt-out) with no controls', () => {
    render(<E2PennyJar data={{ type: 'e2_penny_jar', error: 'You must be logged in to touch the pennies.' }} />)
    expect(screen.getByText(/logged in to touch the pennies/i)).toBeInTheDocument()
    expect(screen.queryByRole('button')).toBeNull()
  })
})
