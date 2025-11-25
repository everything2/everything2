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

jest.mock('../LinkNode', () => ({ type, title, id, display }) => (
  <a href={type ? `/node/${type}/${title}` : `/node/${id}`}>{display || title}</a>
))

import { useChatterPolling } from '../../hooks/useChatterPolling'

describe('Chatterbox', () => {
  // Mock chatter in API order (newest first, DESC by message_id)
  const mockChatter = [
    {
      message_id: 2,
      msgtext: 'How are you?',
      author_user: { node_id: 456, title: 'otheruser', type: 'user' },
      timestamp: '2025-11-24T12:01:00Z'
    },
    {
      message_id: 1,
      msgtext: 'Hello world',
      author_user: { node_id: 123, title: 'testuser', type: 'user' },
      timestamp: '2025-11-24T12:00:00Z'
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
    expect(screen.getByText('and all is quiet...')).toBeInTheDocument()
  })

  it('sends message via chatter API', async () => {
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

    const { container } = render(<Chatterbox showNodelet={true} nodeletIsOpen={true} isGuest={false} />)

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

    // Note: Focus restoration tested manually - jsdom doesn't handle focus well
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

  it('displays messages in chronological order (oldest to newest)', () => {
    useChatterPolling.mockReturnValue({
      chatter: mockChatter, // API returns newest first
      loading: false,
      error: null,
      refresh: mockRefresh
    })

    const { container } = render(<Chatterbox showNodelet={true} nodeletIsOpen={true} />)
    const messages = container.querySelectorAll('[style*="border-bottom"]')

    // After reversing, first message should be "Hello world" (oldest)
    expect(messages[0]).toHaveTextContent('Hello world')
    // Last message should be "How are you?" (newest)
    expect(messages[1]).toHaveTextContent('How are you?')
  })

  it('handles /clearchatter command for admins', async () => {
    useChatterPolling.mockReturnValue({
      chatter: mockChatter,
      loading: false,
      error: null,
      refresh: mockRefresh
    })

    global.fetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({ success: 1, deleted: 5 })
    })

    render(<Chatterbox showNodelet={true} nodeletIsOpen={true} isGuest={false} />)

    const input = screen.getByPlaceholderText('Type a message...')
    const button = screen.getByText('talk')

    fireEvent.change(input, { target: { value: '/clearchatter' } })
    fireEvent.click(button)

    await waitFor(() => {
      expect(global.fetch).toHaveBeenCalledWith('/api/chatter/clear_all', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        credentials: 'same-origin'
      })
    })

    await waitFor(() => {
      expect(mockRefresh).toHaveBeenCalled()
    })
  })

  it('handles /clearchatter 403 error gracefully', async () => {
    useChatterPolling.mockReturnValue({
      chatter: [],
      loading: false,
      error: null,
      refresh: mockRefresh
    })

    const consoleWarnSpy = jest.spyOn(console, 'warn').mockImplementation()

    global.fetch.mockResolvedValueOnce({
      ok: false,
      status: 403
    })

    render(<Chatterbox showNodelet={true} nodeletIsOpen={true} isGuest={false} />)

    const input = screen.getByPlaceholderText('Type a message...')
    const button = screen.getByText('talk')

    fireEvent.change(input, { target: { value: '/clearchatter' } })
    fireEvent.click(button)

    await waitFor(() => {
      expect(consoleWarnSpy).toHaveBeenCalledWith('Clear chatter requires admin access')
    })

    consoleWarnSpy.mockRestore()
  })
})
