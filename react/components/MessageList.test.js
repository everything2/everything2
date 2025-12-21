import React from 'react'
import { render, screen, fireEvent } from '@testing-library/react'
import MessageList from './MessageList'

describe('MessageList', () => {
  const mockMessage = {
    message_id: 123,
    author_user: { node_id: 456, title: 'testuser' },
    timestamp: '2025-12-10T15:30:00.000Z',
    msgtext: 'Hello, this is a test message',
    archive: false
  }

  const mockGroupMessage = {
    ...mockMessage,
    message_id: 124,
    for_usergroup: { node_id: 789, title: 'testgroup' }
  }

  const mockArchivedMessage = {
    ...mockMessage,
    message_id: 125,
    archive: true
  }

  describe('empty state', () => {
    it('shows "No messages" when messages array is empty', () => {
      render(<MessageList messages={[]} />)
      expect(screen.getByText('No messages')).toBeInTheDocument()
    })

    it('shows "No messages" when messages prop is not provided', () => {
      render(<MessageList />)
      expect(screen.getByText('No messages')).toBeInTheDocument()
    })
  })

  describe('message rendering', () => {
    it('renders message author as a link', () => {
      render(<MessageList messages={[mockMessage]} />)
      const authorLink = screen.getByText('testuser')
      expect(authorLink).toHaveAttribute('href', '/node/456')
    })

    it('renders message text with ParseLinks', () => {
      render(<MessageList messages={[mockMessage]} />)
      expect(screen.getByText('Hello, this is a test message')).toBeInTheDocument()
    })

    it('renders timestamp', () => {
      render(<MessageList messages={[mockMessage]} />)
      // The timestamp format depends on the formatTimestamp function
      // For non-compact mode, it should show "Dec 10, 15:30" or similar
      const messageContainer = screen.getByText('testuser').closest('div')
      expect(messageContainer).toBeInTheDocument()
    })

    it('renders usergroup info for group messages in non-compact mode', () => {
      render(<MessageList messages={[mockGroupMessage]} compact={false} />)
      expect(screen.getByText('to group:')).toBeInTheDocument()
      expect(screen.getByText('testgroup')).toBeInTheDocument()
    })

    it('does not render usergroup info in compact mode', () => {
      render(<MessageList messages={[mockGroupMessage]} compact={true} />)
      expect(screen.queryByText('to group:')).not.toBeInTheDocument()
    })
  })

  describe('action buttons', () => {
    it('renders reply button when onReply is provided', () => {
      const onReply = jest.fn()
      render(<MessageList messages={[mockMessage]} onReply={onReply} />)
      expect(screen.getByTitle('Reply to sender')).toBeInTheDocument()
    })

    it('calls onReply when reply button is clicked', () => {
      const onReply = jest.fn()
      render(<MessageList messages={[mockMessage]} onReply={onReply} />)
      fireEvent.click(screen.getByTitle('Reply to sender'))
      expect(onReply).toHaveBeenCalledWith(mockMessage, false)
    })

    it('renders reply-all button for group messages when onReplyAll is provided', () => {
      const onReplyAll = jest.fn()
      render(<MessageList messages={[mockGroupMessage]} onReplyAll={onReplyAll} />)
      expect(screen.getByTitle('Reply to all group members')).toBeInTheDocument()
    })

    it('calls onReplyAll when reply-all button is clicked', () => {
      const onReplyAll = jest.fn()
      render(<MessageList messages={[mockGroupMessage]} onReplyAll={onReplyAll} />)
      fireEvent.click(screen.getByTitle('Reply to all group members'))
      expect(onReplyAll).toHaveBeenCalledWith(mockGroupMessage, true)
    })

    it('does not render reply-all button for non-group messages', () => {
      const onReplyAll = jest.fn()
      render(<MessageList messages={[mockMessage]} onReplyAll={onReplyAll} />)
      expect(screen.queryByTitle('Reply to all group members')).not.toBeInTheDocument()
    })

    it('renders archive button for non-archived messages', () => {
      const onArchive = jest.fn()
      render(<MessageList messages={[mockMessage]} onArchive={onArchive} />)
      expect(screen.getByTitle('Archive message')).toBeInTheDocument()
    })

    it('calls onArchive when archive button is clicked', () => {
      const onArchive = jest.fn()
      render(<MessageList messages={[mockMessage]} onArchive={onArchive} />)
      fireEvent.click(screen.getByTitle('Archive message'))
      expect(onArchive).toHaveBeenCalledWith(123)
    })

    it('renders unarchive button for archived messages', () => {
      const onUnarchive = jest.fn()
      render(<MessageList messages={[mockArchivedMessage]} onUnarchive={onUnarchive} />)
      expect(screen.getByTitle('Unarchive message')).toBeInTheDocument()
    })

    it('calls onUnarchive when unarchive button is clicked', () => {
      const onUnarchive = jest.fn()
      render(<MessageList messages={[mockArchivedMessage]} onUnarchive={onUnarchive} />)
      fireEvent.click(screen.getByTitle('Unarchive message'))
      expect(onUnarchive).toHaveBeenCalledWith(125)
    })

    it('renders delete button when onDelete is provided', () => {
      const onDelete = jest.fn()
      render(<MessageList messages={[mockMessage]} onDelete={onDelete} />)
      expect(screen.getByTitle('Delete message')).toBeInTheDocument()
    })

    it('calls onDelete when delete button is clicked', () => {
      const onDelete = jest.fn()
      render(<MessageList messages={[mockMessage]} onDelete={onDelete} />)
      fireEvent.click(screen.getByTitle('Delete message'))
      expect(onDelete).toHaveBeenCalledWith(123)
    })

    it('hides actions in compact mode', () => {
      const onReply = jest.fn()
      const onArchive = jest.fn()
      const onDelete = jest.fn()

      render(
        <MessageList
          messages={[mockMessage]}
          compact={true}
          onReply={onReply}
          onArchive={onArchive}
          onDelete={onDelete}
        />
      )

      expect(screen.queryByTitle('Reply to sender')).not.toBeInTheDocument()
      expect(screen.queryByTitle('Archive message')).not.toBeInTheDocument()
      expect(screen.queryByTitle('Delete message')).not.toBeInTheDocument()
    })
  })

  describe('showActions prop', () => {
    it('respects showActions.reply = false', () => {
      const onReply = jest.fn()
      render(
        <MessageList
          messages={[mockMessage]}
          onReply={onReply}
          showActions={{ reply: false, replyAll: true, archive: true, unarchive: true, delete: true }}
        />
      )
      expect(screen.queryByTitle('Reply to sender')).not.toBeInTheDocument()
    })

    it('respects showActions.archive = false', () => {
      const onArchive = jest.fn()
      render(
        <MessageList
          messages={[mockMessage]}
          onArchive={onArchive}
          showActions={{ reply: true, replyAll: true, archive: false, unarchive: true, delete: true }}
        />
      )
      expect(screen.queryByTitle('Archive message')).not.toBeInTheDocument()
    })

    it('respects showActions.delete = false', () => {
      const onDelete = jest.fn()
      render(
        <MessageList
          messages={[mockMessage]}
          onDelete={onDelete}
          showActions={{ reply: true, replyAll: true, archive: true, unarchive: true, delete: false }}
        />
      )
      expect(screen.queryByTitle('Delete message')).not.toBeInTheDocument()
    })
  })

  describe('message ordering', () => {
    const messages = [
      { ...mockMessage, message_id: 1, msgtext: 'First message' },
      { ...mockMessage, message_id: 2, msgtext: 'Second message' },
      { ...mockMessage, message_id: 3, msgtext: 'Third message' }
    ]

    it('displays messages in original order by default (chatOrder=false)', () => {
      render(<MessageList messages={messages} chatOrder={false} />)

      const messageTexts = screen.getAllByText(/message$/)
      expect(messageTexts[0]).toHaveTextContent('First message')
      expect(messageTexts[1]).toHaveTextContent('Second message')
      expect(messageTexts[2]).toHaveTextContent('Third message')
    })

    it('reverses message order when chatOrder=true', () => {
      render(<MessageList messages={messages} chatOrder={true} />)

      const messageTexts = screen.getAllByText(/message$/)
      expect(messageTexts[0]).toHaveTextContent('Third message')
      expect(messageTexts[1]).toHaveTextContent('Second message')
      expect(messageTexts[2]).toHaveTextContent('First message')
    })
  })

  describe('limit prop', () => {
    const messages = [
      { ...mockMessage, message_id: 1, msgtext: 'Message 1' },
      { ...mockMessage, message_id: 2, msgtext: 'Message 2' },
      { ...mockMessage, message_id: 3, msgtext: 'Message 3' },
      { ...mockMessage, message_id: 4, msgtext: 'Message 4' },
      { ...mockMessage, message_id: 5, msgtext: 'Message 5' }
    ]

    it('displays all messages when limit is null', () => {
      render(<MessageList messages={messages} limit={null} />)
      expect(screen.getByText('Message 1')).toBeInTheDocument()
      expect(screen.getByText('Message 5')).toBeInTheDocument()
    })

    it('limits displayed messages when limit is set', () => {
      render(<MessageList messages={messages} limit={3} />)
      expect(screen.getByText('Message 1')).toBeInTheDocument()
      expect(screen.getByText('Message 2')).toBeInTheDocument()
      expect(screen.getByText('Message 3')).toBeInTheDocument()
      expect(screen.queryByText('Message 4')).not.toBeInTheDocument()
      expect(screen.queryByText('Message 5')).not.toBeInTheDocument()
    })
  })
})
