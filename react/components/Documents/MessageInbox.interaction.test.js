import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import MessageInbox from './MessageInbox'

// MessageInbox seeds its message list + counts from `data` (no mount fetch); network calls
// fire only on interaction (tab change -> reload, archive -> POST). Mock MessageList to surface
// the messages it receives + an archive trigger, so we unit-test MessageInbox's orchestration
// (seeding, the archive round-trip, tab-driven reload) without MessageList's own rendering.
jest.mock('../MessageList', () => (props) => (
  <div data-testid="mlist" data-count={String(props.messages.length)}>
    {props.messages[0] && (
      <button onClick={() => props.onArchive(props.messages[0].message_id)}>archive-first</button>
    )}
  </div>
))
// Heavy sibling children aren't under test here; stub them to inert nodes.
jest.mock('../MessageModal', () => () => null)
jest.mock('../ConfirmActionModal', () => () => null)
jest.mock('../UserSearchInput', () => () => null)

const inboxData = (overrides = {}) => ({
  defaultTab: 'inbox',
  pageSize: 25,
  inbox: {
    messages: [
      { message_id: 101, author: { title: 'alice', node_id: 1 }, msgtext: 'hi there', tstamp: '2020-01-01 00:00:00' },
      { message_id: 102, author: { title: 'bob', node_id: 2 }, msgtext: 'yo', tstamp: '2020-01-02 00:00:00' },
    ],
    count: 2,
    archivedCount: 1,
  },
  outbox: { messages: [], count: 0 },
  accessibleBots: [],
  ...overrides,
})

describe('MessageInbox', () => {
  afterEach(() => {
    jest.restoreAllMocks()
    delete global.fetch
  })

  it('shows the guest prompt (and no network) for a guest payload', () => {
    global.fetch = jest.fn()
    render(<MessageInbox data={{ error: 'guest', message: 'You must be logged in.' }} />)
    expect(screen.getByRole('heading', { name: /message inbox/i })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: /log in/i })).toBeInTheDocument()
    expect(global.fetch).not.toHaveBeenCalled()
  })

  it('seeds the message list + inbox count from data (no mount fetch)', () => {
    global.fetch = jest.fn()
    render(<MessageInbox data={inboxData()} />)
    expect(screen.getByTestId('mlist')).toHaveAttribute('data-count', '2')
    // inbox tab badge reflects the seeded count
    expect(screen.getByText('(2)')).toBeInTheDocument()
    expect(global.fetch).not.toHaveBeenCalled()
  })

  it('archives a message: POSTs the action and drops it from the list', async () => {
    global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: true }) })
    render(<MessageInbox data={inboxData()} />)
    fireEvent.click(screen.getByRole('button', { name: 'archive-first' }))

    await waitFor(() =>
      expect(global.fetch).toHaveBeenCalledWith(
        '/api/messages/101/action/archive',
        expect.objectContaining({ method: 'POST' })
      )
    )
    // message removed locally and the active-tab count decremented
    await waitFor(() => expect(screen.getByTestId('mlist')).toHaveAttribute('data-count', '1'))
    expect(screen.getByText('(1)')).toBeInTheDocument()
  })

  it('switching to the Sent tab reloads via /api/messages/ with the outbox flag', async () => {
    // tab change -> loadMessages: one messages fetch + three count fetches
    global.fetch = jest.fn((url) =>
      Promise.resolve({
        ok: true,
        json: async () => (String(url).includes('/count') ? { count: 0 } : []),
      })
    )
    render(<MessageInbox data={inboxData()} />)
    fireEvent.click(screen.getByRole('button', { name: /sent/i }))

    await waitFor(() => expect(global.fetch).toHaveBeenCalled())
    const messagesCall = global.fetch.mock.calls
      .map((c) => String(c[0]))
      .find((u) => u.startsWith('/api/messages/?'))
    expect(messagesCall).toBeTruthy()
    expect(messagesCall).toContain('outbox=1')
  })
})
