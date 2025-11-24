import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import '@testing-library/jest-dom'
import Chatterbox from './Chatterbox'

// Mock the hooks
jest.mock('../../hooks/useChatterPolling', () => ({
  useChatterPolling: jest.fn()
}))

// Mock child components
jest.mock('../NodeletContainer', () => ({ children, title }) => (
  <div data-testid="nodelet-container">
    <h3>{title}</h3>
    {children}
  </div>
))

jest.mock('../LinkNode', () => ({ node }) => (
  <a href={`/node/${node.type}/${node.title}`}>{node.title}</a>
))

import { useChatterPolling } from '../../hooks/useChatterPolling'

describe('Chatterbox', () => {
  const mockChatter = [
    {
      message_id: 1,
      msgtext: 'Hello world',
      author_user: { node_id: 123, title: 'testuser', type: 'user' },
      timestamp: '2025-11-24T12:00:00Z'
    },
    {
      message_id: 2,
      msgtext: 'How are you?',
      author_user: { node_id: 456, title: 'otheruser', type: 'user' },
      timestamp: '2025-11-24T12:01:00Z'
    }
  ]

  const mockRefresh = jest.fn()

  beforeEach(() => {
    jest.clearAllMocks()
    global.fetch = jest.fn()
  })

  afterEach(() => {
    global.fetch.mockRestore?.()
  })

  it('renders loading state', () => {
    useChatterPolling.mockReturnValue({
      chatter: [],
      loading: true,
      error: null,
      refresh: mockRefresh
    })

    render(<Chatterbox showNodelet={true} nodeletIsOpen={true} />)
    expect(screen.getByText('Loading chatter...')).toBeInTheDocument()
  })

  it('renders chatter messages', () => {
    useChatterPolling.mockReturnValue({
      chatter: mockChatter,
      loading: false,
      error: null,
      refresh: mockRefresh
    })

    render(<Chatterbox showNodelet={true} nodeletIsOpen={true} />)

    expect(screen.getByText('Hello world')).toBeInTheDocument()
    expect(screen.getByText('How are you?')).toBeInTheDocument()
    expect(screen.getByText('testuser')).toBeInTheDocument()
    expect(screen.getByText('otheruser')).toBeInTheDocument()
  })

  it('renders error state', () => {
    useChatterPolling.mockReturnValue({
      chatter: [],
      loading: false,
      error: 'Network error',
      refresh: mockRefresh
    })

    render(<Chatterbox showNodelet={true} nodeletIsOpen={true} />)
    expect(screen.getByText(/Error loading chatter: Network error/)).toBeInTheDocument()
  })

  it('renders empty state', () => {
    useChatterPolling.mockReturnValue({
      chatter: [],
      loading: false,
      error: null,
      refresh: mockRefresh
    })

    render(<Chatterbox showNodelet={true} nodeletIsOpen={true} />)
    expect(screen.getByText('No recent chatter')).toBeInTheDocument()
  })

  it('sends message via API', async () => {
    useChatterPolling.mockReturnValue({
      chatter: [],
      loading: false,
      error: null,
      refresh: mockRefresh
    })

    global.fetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({ success: true })
    })

    render(<Chatterbox showNodelet={true} nodeletIsOpen={true} isGuest={false} />)

    const input = screen.getByPlaceholderText('Type a message...')
    const button = screen.getByText('talk')

    fireEvent.change(input, { target: { value: 'Test message' } })
    fireEvent.click(button)

    await waitFor(() => {
      expect(global.fetch).toHaveBeenCalledWith('/api/chatter/create', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        credentials: 'same-origin',
        body: JSON.stringify({ message: 'Test message' })
      })
    })

    await waitFor(() => {
      expect(mockRefresh).toHaveBeenCalled()
    })
  })

  it('shows borged message when user is borged', () => {
    useChatterPolling.mockReturnValue({
      chatter: [],
      loading: false,
      error: null,
      refresh: mockRefresh
    })

    render(<Chatterbox showNodelet={true} nodeletIsOpen={true} borged={true} />)
    expect(screen.getByText(/You're borged/)).toBeInTheDocument()
  })

  it('shows suspension message when user is chat suspended', () => {
    useChatterPolling.mockReturnValue({
      chatter: [],
      loading: false,
      error: null,
      refresh: mockRefresh
    })

    render(<Chatterbox showNodelet={true} nodeletIsOpen={true} chatSuspended={true} />)
    expect(screen.getByText(/You are currently suspended from public chat/)).toBeInTheDocument()
  })

  it('does not show input form for guest users', () => {
    useChatterPolling.mockReturnValue({
      chatter: [],
      loading: false,
      error: null,
      refresh: mockRefresh
    })

    render(<Chatterbox showNodelet={true} nodeletIsOpen={true} isGuest={true} />)
    expect(screen.getByText('Please log in to use the chatterbox')).toBeInTheDocument()
    expect(screen.queryByPlaceholderText('Type a message...')).not.toBeInTheDocument()
  })
})
