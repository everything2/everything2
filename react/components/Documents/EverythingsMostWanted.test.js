import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import EverythingsMostWanted from './EverythingsMostWanted'
import fixture from '../../__fixtures__/pagestate/everything_s_most_wanted.json'

// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate
// payload, pinning the int-typed contract (#4152/#4108).
describe('EverythingsMostWanted (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<EverythingsMostWanted data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<EverythingsMostWanted data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// API-backed behaviour: actions POST to /api/bounties/* and the read model is
// refreshed from GET /api/bounties (#4198).
describe('EverythingsMostWanted (API-backed)', () => {
  // POST -> {success, message}; GET -> a refreshed read model.
  const mockFetch = () =>
    (global.fetch = jest.fn((url, opts) => {
      if (opts && opts.method === 'POST') {
        return Promise.resolve({ json: async () => ({ success: 1, message: 'Bounty office acknowledges.' }) })
      }
      return Promise.resolve({
        json: async () => ({ success: 1, bounties: [], justice_served: [], can_post: 1, has_bounty: 0 })
      })
    }))

  afterEach(() => jest.restoreAllMocks())

  const base = { bounties: [], justice_served: [], can_post: 1, has_bounty: 0, bounty_limit: 100 }

  it('posts a new bounty with the entered fields', async () => {
    const f = mockFetch()
    render(<EverythingsMostWanted data={{ ...base }} />)

    fireEvent.click(screen.getByRole('button', { name: /Add a Bounty/ }))
    fireEvent.change(screen.getByPlaceholderText(/Enter nodeshell title/), { target: { value: 'Some Nodeshell' } })
    fireEvent.change(screen.getByPlaceholderText('0'), { target: { value: '7' } })
    fireEvent.click(screen.getByRole('button', { name: /Post Bounty/ }))

    await waitFor(() => expect(screen.getByText(/Bounty office acknowledges/)).toBeInTheDocument())

    const post = f.mock.calls.find(([, o]) => o && o.method === 'POST')
    expect(post[0]).toBe('/api/bounties')
    expect(JSON.parse(post[1].body)).toEqual({ outlaw: 'Some Nodeshell', reward: '7', comment: '' })
  })

  it('removes your own bounty', async () => {
    const f = mockFetch()
    render(<EverythingsMostWanted data={{ ...base, has_bounty: 1, current_bounty: { outlaw: '[x]', reward: 0 } }} />)

    fireEvent.click(screen.getByRole('button', { name: /Just remove it/ }))

    await waitFor(() => expect(f.mock.calls.some(([u, o]) => u === '/api/bounties/remove' && o.method === 'POST')).toBe(true))
  })

  it('sheriff yanks another user bounty by name', async () => {
    const f = mockFetch()
    render(<EverythingsMostWanted data={{ ...base, is_sheriff: 1 }} />)

    fireEvent.change(screen.getByRole('textbox'), { target: { value: 'baddie' } })
    fireEvent.click(screen.getByRole('button', { name: /Remove Bounty/ }))

    await waitFor(() => {
      const yank = f.mock.calls.find(([u, o]) => u === '/api/bounties/yank' && o.method === 'POST')
      expect(yank).toBeTruthy()
      expect(JSON.parse(yank[1].body)).toEqual({ removee: 'baddie' })
    })
  })

  it('surfaces an API error', async () => {
    global.fetch = jest.fn(() => Promise.resolve({ json: async () => ({ success: 0, error: 'You are not yet eligible to post bounties.' }) }))
    render(<EverythingsMostWanted data={{ ...base }} />)
    fireEvent.click(screen.getByRole('button', { name: /Add a Bounty/ }))
    fireEvent.change(screen.getByPlaceholderText(/Enter nodeshell title/), { target: { value: 'X' } })
    fireEvent.click(screen.getByRole('button', { name: /Post Bounty/ }))
    await waitFor(() => expect(screen.getByRole('alert')).toHaveTextContent('not yet eligible'))
  })
})
