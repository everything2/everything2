import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import E2Poll from './E2Poll'

// E2Poll's own responsibility is the vote/delete-vote handlers it passes down to PollDisplay:
// POST /api/poll/vote (updating results in place on success) and POST /api/poll/delete_vote
// (admin, reload on success). Mock PollDisplay to surface those callbacks + the current
// totalvotes, so we unit-test E2Poll's logic without PollDisplay's rendering (covered by its
// own test). The existing E2Poll.test.js keeps exercising the real child.
jest.mock('../Poll/PollDisplay', () => (props) => (
  <div data-testid="poll" data-totalvotes={String(props.poll.totalvotes)}>
    <button onClick={() => props.onVote(props.poll.poll_id, 1)}>vote</button>
    <button onClick={() => props.onDeleteVote(props.poll.poll_id, 7)}>delvote</button>
  </div>
))

const baseData = {
  poll: {
    poll_id: 42,
    title: 'Fav color',
    question: 'Q',
    options: ['red', 'blue'],
    results: { 1: 3, 2: 2 },
    totalvotes: 5,
    poll_status: 'open',
    poll_author: { node_id: 9, title: 'author' },
    user_vote: null,
  },
  user: { is_guest: false, is_admin: false, node_id: 100 },
}

describe('E2Poll voting interaction', () => {
  afterEach(() => {
    jest.restoreAllMocks()
    delete global.fetch
  })

  it('posts a vote and updates the tally in place on success', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ success: true, poll: { totalvotes: 6, e2poll_results: { 1: 4, 2: 2 }, userVote: 1 } }),
    })
    render(<E2Poll data={baseData} user={{ admin: false }} />)
    expect(screen.getByTestId('poll')).toHaveAttribute('data-totalvotes', '5')

    fireEvent.click(screen.getByRole('button', { name: 'vote' }))
    await waitFor(() =>
      expect(global.fetch).toHaveBeenCalledWith('/api/poll/vote', expect.objectContaining({ method: 'POST' }))
    )
    const body = JSON.parse(global.fetch.mock.calls[0][1].body)
    expect(body).toEqual({ poll_id: 42, choice: 1 })
    // the child re-renders with the server's new tally
    await waitFor(() => expect(screen.getByTestId('poll')).toHaveAttribute('data-totalvotes', '6'))
  })

  it('shows the API error when a vote is rejected', async () => {
    global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: false, error: 'Poll is closed' }) })
    render(<E2Poll data={baseData} user={{ admin: false }} />)
    fireEvent.click(screen.getByRole('button', { name: 'vote' }))
    await waitFor(() => expect(screen.getByText('Poll is closed')).toBeInTheDocument())
  })

  it('deletes a vote (admin) and reloads on success', async () => {
    global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: true }) })
    const orig = window.location
    Object.defineProperty(window, 'location', {
      value: { ...orig, reload: jest.fn() },
      writable: true,
      configurable: true,
    })
    try {
      render(<E2Poll data={baseData} user={{ admin: true }} />)
      fireEvent.click(screen.getByRole('button', { name: 'delvote' }))
      await waitFor(() =>
        expect(global.fetch).toHaveBeenCalledWith('/api/poll/delete_vote', expect.objectContaining({ method: 'POST' }))
      )
      const body = JSON.parse(global.fetch.mock.calls[0][1].body)
      expect(body).toEqual({ poll_id: 42, voter_user: 7 })
      await waitFor(() => expect(window.location.reload).toHaveBeenCalled())
    } finally {
      Object.defineProperty(window, 'location', { value: orig, writable: true, configurable: true })
    }
  })
})
