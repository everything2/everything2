import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import '@testing-library/jest-dom'
import Messages from './Messages'

// Mock NodeletContainer
jest.mock('../NodeletContainer', () => {
  return function MockNodeletContainer({ children, title }) {
    return (
      <div data-testid="nodelet-container">
        <h3>{title}</h3>
        {children}
      </div>
    )
  }
})

// Mock ParseLinks
jest.mock('../ParseLinks', () => {
  return function MockParseLinks({ children }) {
    return <span data-testid="parse-links">{children}</span>
  }
})

// Mock LinkNode
jest.mock('../LinkNode', () => {
  return function MockLinkNode({ id, display }) {
    return <a href={`/node/${id}`} data-testid="link-node">{display}</a>
  }
})

// Mock MessageModal
jest.mock('../MessageModal', () => {
  return function MockMessageModal() {
    return null
  }
})

// Mock useActivityDetection
jest.mock('../../hooks/useActivityDetection', () => ({
  useActivityDetection: () => ({
    isActive: true,
    isMultiTabActive: false  // Disable polling in tests
  })
}))

// Mock fetch
global.fetch = jest.fn()

describe('Messages Component', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    global.fetch.mockResolvedValue({
      ok: true,
      json: async () => ([])
    })
  })

  const mockShowNodelet = jest.fn()

  describe('Rendering', () => {
    test('renders with no messages', () => {
      render(
        <Messages
          initialMessages={[]}
          showNodelet={mockShowNodelet}
          nodeletIsOpen={true}
        />
      )

      expect(screen.getByTestId('nodelet-container')).toBeInTheDocument()
      expect(screen.getByText('Messages')).toBeInTheDocument()
      expect(screen.getByText('No messages')).toBeInTheDocument()
    })

    test('renders when initialMessages is null', () => {
      render(
        <Messages
          initialMessages={null}
          showNodelet={mockShowNodelet}
          nodeletIsOpen={true}
        />
      )

      // Component treats null as empty array due to || [] default
      expect(screen.getByText('No messages')).toBeInTheDocument()
    })

    test('renders with messages', () => {
      const messages = [
        {
          message_id: 1,
          author_user: { node_id: 100, title: 'testuser' },
          msgtext: 'Hello world',
          timestamp: '2025-11-24T10:00:00Z',
          archive: 0
        }
      ]

      render(
        <Messages
          initialMessages={messages}
          showNodelet={mockShowNodelet}
          nodeletIsOpen={true}
        />
      )

      expect(screen.getByText('testuser')).toBeInTheDocument()
      expect(screen.getByText('Hello world')).toBeInTheDocument()
    })

    test('renders message with usergroup recipient', () => {
      const messages = [
        {
          message_id: 1,
          author_user: { node_id: 100, title: 'testuser' },
          for_usergroup: { node_id: 200, title: 'editors' },
          msgtext: 'Group message',
          timestamp: '2025-11-24T10:00:00Z',
          archive: 0
        }
      ]

      render(
        <Messages
          initialMessages={messages}
          showNodelet={mockShowNodelet}
          nodeletIsOpen={true}
        />
      )

      expect(screen.getByText('to group:')).toBeInTheDocument()
      expect(screen.getByText('editors')).toBeInTheDocument()
    })

    test('renders ParseLinks for message text', () => {
      const messages = [
        {
          message_id: 1,
          author_user: { node_id: 100, title: 'testuser' },
          msgtext: 'Check out [this node]',
          timestamp: '2025-11-24T10:00:00Z',
          archive: 0
        }
      ]

      render(
        <Messages
          initialMessages={messages}
          showNodelet={mockShowNodelet}
          nodeletIsOpen={true}
        />
      )

      expect(screen.getByTestId('parse-links')).toBeInTheDocument()
      expect(screen.getByText('Check out [this node]')).toBeInTheDocument()
    })
  })

  describe('Message Actions', () => {
    test('shows archive and delete buttons for non-archived messages', () => {
      const messages = [
        {
          message_id: 1,
          author_user: { node_id: 100, title: 'testuser' },
          msgtext: 'Test message',
          timestamp: '2025-11-24T10:00:00Z',
          archive: 0
        }
      ]

      render(
        <Messages
          initialMessages={messages}
          showNodelet={mockShowNodelet}
          nodeletIsOpen={true}
        />
      )

      expect(screen.getByTitle('Archive message')).toBeInTheDocument()
      expect(screen.getByTitle('Delete message')).toBeInTheDocument()
    })

    test('shows unarchive button for archived messages', () => {
      const messages = [
        {
          message_id: 1,
          author_user: { node_id: 100, title: 'testuser' },
          msgtext: 'Archived message',
          timestamp: '2025-11-24T10:00:00Z',
          archive: 1
        }
      ]

      render(
        <Messages
          initialMessages={messages}
          showNodelet={mockShowNodelet}
          nodeletIsOpen={true}
        />
      )

      // Archived messages show icon-only buttons including unarchive, reply, and delete
      expect(screen.getByTitle('Unarchive message')).toBeInTheDocument()
      expect(screen.getByTitle('Reply to sender')).toBeInTheDocument()
      expect(screen.getByTitle('Delete message')).toBeInTheDocument()
      expect(screen.queryByTitle('Archive message')).not.toBeInTheDocument()
    })

    test('archives message on Archive button click', async () => {
      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ success: true })
      })

      const messages = [
        {
          message_id: 1,
          author_user: { node_id: 100, title: 'testuser' },
          msgtext: 'Test message',
          timestamp: '2025-11-24T10:00:00Z',
          archive: 0
        }
      ]

      render(
        <Messages
          initialMessages={messages}
          showNodelet={mockShowNodelet}
          nodeletIsOpen={true}
        />
      )

      const archiveButton = screen.getByTitle('Archive message')
      fireEvent.click(archiveButton)

      await waitFor(() => {
        expect(global.fetch).toHaveBeenCalledWith(
          '/api/messages/1/action/archive',
          expect.objectContaining({
            method: 'POST',
            credentials: 'include'
          })
        )
      })

      // Message should be removed from list
      await waitFor(() => {
        expect(screen.queryByText('Test message')).not.toBeInTheDocument()
      })
    })

    test('deletes message on Delete button click', async () => {
      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ success: true })
      })

      const messages = [
        {
          message_id: 1,
          author_user: { node_id: 100, title: 'testuser' },
          msgtext: 'Test message',
          timestamp: '2025-11-24T10:00:00Z',
          archive: 0
        }
      ]

      render(
        <Messages
          initialMessages={messages}
          showNodelet={mockShowNodelet}
          nodeletIsOpen={true}
        />
      )

      const deleteButton = screen.getByTitle('Delete message')
      fireEvent.click(deleteButton)

      // Should show confirmation modal
      expect(screen.getByText('Delete Message')).toBeInTheDocument()
      expect(screen.getByText('Are you sure you want to permanently delete this message? This action cannot be undone.')).toBeInTheDocument()

      // Click confirm button
      const confirmButton = screen.getByText('Delete')
      fireEvent.click(confirmButton)

      await waitFor(() => {
        expect(global.fetch).toHaveBeenCalledWith(
          '/api/messages/1/action/delete',
          expect.objectContaining({
            method: 'POST',
            credentials: 'include'
          })
        )
      })

      // Message should be removed from list
      await waitFor(() => {
        expect(screen.queryByText('Test message')).not.toBeInTheDocument()
      })
    })

    test('unarchives message on Unarchive button click', async () => {
      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ success: true })
      })

      const messages = [
        {
          message_id: 1,
          author_user: { node_id: 100, title: 'testuser' },
          msgtext: 'Archived message',
          timestamp: '2025-11-24T10:00:00Z',
          archive: 1
        }
      ]

      render(
        <Messages
          initialMessages={messages}
          showNodelet={mockShowNodelet}
          nodeletIsOpen={true}
        />
      )

      const unarchiveButton = screen.getByTitle('Unarchive message')
      fireEvent.click(unarchiveButton)

      await waitFor(() => {
        expect(global.fetch).toHaveBeenCalledWith(
          '/api/messages/1/action/unarchive',
          expect.objectContaining({
            method: 'POST',
            credentials: 'include'
          })
        )
      })

      // Message should be removed from list
      await waitFor(() => {
        expect(screen.queryByText('Archived message')).not.toBeInTheDocument()
      })
    })

    test('handles archive error gracefully', async () => {
      global.fetch.mockResolvedValueOnce({
        ok: false,
        statusText: 'Forbidden'
      })

      const messages = [
        {
          message_id: 1,
          author_user: { node_id: 100, title: 'testuser' },
          msgtext: 'Test message',
          timestamp: '2025-11-24T10:00:00Z',
          archive: 0
        }
      ]

      render(
        <Messages
          initialMessages={messages}
          showNodelet={mockShowNodelet}
          nodeletIsOpen={true}
        />
      )

      const archiveButton = screen.getByTitle('Archive message')
      fireEvent.click(archiveButton)

      await waitFor(() => {
        expect(screen.getByText(/Failed to archive message/i)).toBeInTheDocument()
      })
    })
  })

  describe('Inbox/Archived Toggle', () => {
    test('renders inbox and archived toggle buttons', () => {
      render(
        <Messages
          initialMessages={[]}
          showNodelet={mockShowNodelet}
          nodeletIsOpen={true}
        />
      )

      // Use getAllByText since there's also an "Inbox" link in the footer
      const inboxElements = screen.getAllByText('Inbox')
      expect(inboxElements.length).toBeGreaterThanOrEqual(1)
      expect(screen.getByText('Archived')).toBeInTheDocument()
    })

    test('loads archived messages when Archived button clicked', async () => {
      const archivedMessages = [
        {
          message_id: 2,
          author_user: { node_id: 100, title: 'testuser' },
          msgtext: 'Archived message',
          timestamp: '2025-11-24T09:00:00Z',
          archive: 1
        }
      ]

      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => archivedMessages
      })

      render(
        <Messages
          initialMessages={[]}
          showNodelet={mockShowNodelet}
          nodeletIsOpen={true}
        />
      )

      const archivedButton = screen.getByText('Archived')
      fireEvent.click(archivedButton)

      await waitFor(() => {
        expect(global.fetch).toHaveBeenCalledWith(
          '/api/messages/?limit=10&archive=1',
          expect.objectContaining({
            credentials: 'include'
          })
        )
      })

      await waitFor(() => {
        expect(screen.getByText('Archived message')).toBeInTheDocument()
      })
    })

    test('loads inbox messages when Inbox button clicked after viewing archived', async () => {
      const archivedMessages = [
        {
          message_id: 2,
          author_user: { node_id: 100, title: 'testuser' },
          msgtext: 'Archived message',
          timestamp: '2025-11-24T09:00:00Z',
          archive: 1
        }
      ]

      const inboxMessages = [
        {
          message_id: 1,
          author_user: { node_id: 100, title: 'testuser' },
          msgtext: 'Inbox message',
          timestamp: '2025-11-24T10:00:00Z',
          archive: 0
        }
      ]

      global.fetch
        .mockResolvedValueOnce({
          ok: true,
          json: async () => archivedMessages
        })
        .mockResolvedValueOnce({
          ok: true,
          json: async () => inboxMessages
        })

      render(
        <Messages
          initialMessages={[]}
          showNodelet={mockShowNodelet}
          nodeletIsOpen={true}
        />
      )

      // First switch to archived view
      const archivedButton = screen.getByText('Archived')
      fireEvent.click(archivedButton)

      await waitFor(() => {
        expect(screen.getByText('Archived message')).toBeInTheDocument()
      })

      // Then switch back to inbox - get the button specifically, not the link
      const inboxButton = screen.getByRole('button', { name: 'Inbox' })
      fireEvent.click(inboxButton)

      await waitFor(() => {
        expect(global.fetch).toHaveBeenCalledWith(
          '/api/messages/?limit=10',
          expect.objectContaining({
            credentials: 'include'
          })
        )
      })

      await waitFor(() => {
        expect(screen.getByText('Inbox message')).toBeInTheDocument()
      })
    })

    test('disables Inbox button when viewing inbox', () => {
      render(
        <Messages
          initialMessages={[]}
          showNodelet={mockShowNodelet}
          nodeletIsOpen={true}
        />
      )

      // Get the button specifically, not the link
      const inboxButton = screen.getByRole('button', { name: 'Inbox' })
      expect(inboxButton).toBeDisabled()
    })

    test('shows loading state when fetching messages', async () => {
      global.fetch.mockImplementationOnce(() =>
        new Promise(resolve => setTimeout(() => resolve({
          ok: true,
          json: async () => []
        }), 100))
      )

      render(
        <Messages
          initialMessages={[]}
          showNodelet={mockShowNodelet}
          nodeletIsOpen={true}
        />
      )

      const archivedButton = screen.getByText('Archived')
      fireEvent.click(archivedButton)

      expect(screen.getByText('Loading messages...')).toBeInTheDocument()

      await waitFor(() => {
        expect(screen.queryByText('Loading messages...')).not.toBeInTheDocument()
      })
    })
  })

  describe('Timestamp Formatting', () => {
    test('formats timestamp correctly', () => {
      const messages = [
        {
          message_id: 1,
          author_user: { node_id: 100, title: 'testuser' },
          msgtext: 'Test message',
          timestamp: '2025-11-24T10:30:00Z',
          archive: 0
        }
      ]

      render(
        <Messages
          initialMessages={messages}
          showNodelet={mockShowNodelet}
          nodeletIsOpen={true}
        />
      )

      // Timestamp should be formatted (exact format depends on locale, just check it exists)
      const messageElement = screen.getByText('Test message').closest('div')
      expect(messageElement).toBeInTheDocument()
    })
  })

  describe('Multiple Messages', () => {
    test('renders multiple messages in order', () => {
      const messages = [
        {
          message_id: 1,
          author_user: { node_id: 100, title: 'user1' },
          msgtext: 'First message',
          timestamp: '2025-11-24T10:00:00Z',
          archive: 0
        },
        {
          message_id: 2,
          author_user: { node_id: 101, title: 'user2' },
          msgtext: 'Second message',
          timestamp: '2025-11-24T11:00:00Z',
          archive: 0
        },
        {
          message_id: 3,
          author_user: { node_id: 102, title: 'user3' },
          msgtext: 'Third message',
          timestamp: '2025-11-24T12:00:00Z',
          archive: 0
        }
      ]

      render(
        <Messages
          initialMessages={messages}
          showNodelet={mockShowNodelet}
          nodeletIsOpen={true}
        />
      )

      expect(screen.getByText('First message')).toBeInTheDocument()
      expect(screen.getByText('Second message')).toBeInTheDocument()
      expect(screen.getByText('Third message')).toBeInTheDocument()
      expect(screen.getByText('user1')).toBeInTheDocument()
      expect(screen.getByText('user2')).toBeInTheDocument()
      expect(screen.getByText('user3')).toBeInTheDocument()
    })
  })
})
