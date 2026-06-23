import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import SanctifyUser from './SanctifyUser'
import fixture from '../../__fixtures__/pagestate/sanctify_user.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('SanctifyUser (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<SanctifyUser data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<SanctifyUser data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// API-backed behaviour: the form POSTs to /api/sanctify/give and the UI reflects
// the new GP balance on success / surfaces the error on failure (#4198).
describe('SanctifyUser (API-backed)', () => {
  // A user permitted to sanctify: form renders.
  const canSanctifyData = {
    sanctify: {
      canSanctify: true,
      reason: '',
      gp: 50,
      level: 12,
      sanctifyAmount: 10,
      minLevel: 11,
      gpOptOut: false,
      userSanctity: 0
    }
  }

  afterEach(() => jest.restoreAllMocks())

  it('does not render the form when the user cannot sanctify (level gate)', () => {
    render(
      <SanctifyUser
        data={{ sanctify: { canSanctify: false, reason: 'You must be at least Level 11 to sanctify users.', minLevel: 11, sanctifyAmount: 10 } }}
      />
    )
    // brush-off copy for the level case, no submit button
    expect(screen.getByText(/The Pope or something/)).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /Sanctify/ })).toBeNull()
  })

  it('POSTs the recipient + anonymous flag and renders the success balance', async () => {
    const fetchMock = (global.fetch = jest.fn().mockResolvedValue({
      json: async () => ({ success: 1, message: 'You gave 10 GP to bob.', newGP: 40 })
    }))

    render(<SanctifyUser data={canSanctifyData} />)

    fireEvent.change(screen.getByPlaceholderText('Username'), { target: { value: '  bob  ' } })
    fireEvent.click(screen.getByLabelText('Remain anonymous'))
    fireEvent.click(screen.getByRole('button', { name: /Sanctify/ }))

    await waitFor(() => expect(screen.getByText(/You gave 10 GP to bob\./)).toBeInTheDocument())

    // correct request shape: recipient trimmed, anonymous true
    const [url, opts] = fetchMock.mock.calls[0]
    expect(url).toBe('/api/sanctify/give')
    expect(opts.method).toBe('POST')
    expect(JSON.parse(opts.body)).toEqual({ recipient: 'bob', anonymous: true })

    // the new GP balance from the API surfaces in the followup
    expect(screen.getByText(/Would you like to sanctify someone else/)).toBeInTheDocument()
    expect(screen.getByText('40 GP')).toBeInTheDocument()
  })

  it('dispatches an e2:userUpdate event carrying the new GP on success', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      json: async () => ({ success: 1, message: 'Done.', newGP: 25 })
    })
    const listener = jest.fn()
    window.addEventListener('e2:userUpdate', listener)

    render(<SanctifyUser data={canSanctifyData} />)
    fireEvent.change(screen.getByPlaceholderText('Username'), { target: { value: 'carol' } })
    fireEvent.click(screen.getByRole('button', { name: /Sanctify/ }))

    await waitFor(() => expect(listener).toHaveBeenCalled())
    expect(listener.mock.calls[0][0].detail).toEqual({ gp: 25 })
    window.removeEventListener('e2:userUpdate', listener)
  })

  it('surfaces the API error and leaves the form intact', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      json: async () => ({ success: 0, error: 'That user does not exist.' })
    })

    render(<SanctifyUser data={canSanctifyData} />)
    fireEvent.change(screen.getByPlaceholderText('Username'), { target: { value: 'ghost' } })
    fireEvent.click(screen.getByRole('button', { name: /Sanctify/ }))

    await waitFor(() => expect(screen.getByText('That user does not exist.')).toBeInTheDocument())
    // still on the form, no success followup
    expect(screen.queryByText(/Would you like to sanctify someone else/)).toBeNull()
  })

  it('reports a network failure with the generic message', async () => {
    global.fetch = jest.fn().mockRejectedValue(new Error('boom'))

    render(<SanctifyUser data={canSanctifyData} />)
    fireEvent.change(screen.getByPlaceholderText('Username'), { target: { value: 'dave' } })
    fireEvent.click(screen.getByRole('button', { name: /Sanctify/ }))

    await waitFor(() =>
      expect(screen.getByText('An error occurred. Please try again.')).toBeInTheDocument()
    )
  })
})
