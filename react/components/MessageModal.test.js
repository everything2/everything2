import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import MessageModal from './MessageModal'

describe('MessageModal', () => {
  const defaultProps = {
    isOpen: true,
    onClose: jest.fn(),
    onSend: jest.fn()
  }

  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('visibility', () => {
    it('renders nothing when isOpen is false', () => {
      const { container } = render(<MessageModal {...defaultProps} isOpen={false} />)
      expect(container).toBeEmptyDOMElement()
    })

    it('renders modal when isOpen is true', () => {
      render(<MessageModal {...defaultProps} />)
      expect(screen.getByRole('heading', { name: 'New Message' })).toBeInTheDocument()
    })
  })

  describe('new message mode', () => {
    it('shows "New Message" title when not replying', () => {
      render(<MessageModal {...defaultProps} />)
      expect(screen.getByRole('heading', { name: 'New Message' })).toBeInTheDocument()
    })

    it('shows recipient input field for new messages', () => {
      render(<MessageModal {...defaultProps} />)
      expect(screen.getByPlaceholderText('Username or usergroup name')).toBeInTheDocument()
    })

    it('shows message textarea', () => {
      render(<MessageModal {...defaultProps} />)
      expect(screen.getByPlaceholderText('Type your message here...')).toBeInTheDocument()
    })

    it('shows character count', () => {
      render(<MessageModal {...defaultProps} />)
      expect(screen.getByText('0 / 512 characters')).toBeInTheDocument()
    })
  })

  describe('reply mode', () => {
    const replyTo = {
      message_id: 123,
      author_user: { node_id: 456, title: 'testuser', type: 'user' },
      msgtext: 'Original message'
    }

    it('shows "Reply" title when replying to a message', () => {
      render(<MessageModal {...defaultProps} replyTo={replyTo} />)
      expect(screen.getByRole('heading', { name: 'Reply' })).toBeInTheDocument()
    })

    it('shows recipient name instead of input field', () => {
      render(<MessageModal {...defaultProps} replyTo={replyTo} />)
      expect(screen.getByText('testuser')).toBeInTheDocument()
      expect(screen.queryByPlaceholderText('Username or usergroup name')).not.toBeInTheDocument()
    })
  })

  describe('reply all mode', () => {
    const replyToGroup = {
      message_id: 123,
      author_user: { node_id: 456, title: 'testuser', type: 'user' },
      for_usergroup: { node_id: 789, title: 'testgroup' },
      msgtext: 'Original message'
    }

    it('shows "Reply All" title when replying to all', () => {
      render(<MessageModal {...defaultProps} replyTo={replyToGroup} initialReplyAll={true} />)
      expect(screen.getByRole('heading', { name: 'Reply All' })).toBeInTheDocument()
    })

    it('shows group name as recipient', () => {
      render(<MessageModal {...defaultProps} replyTo={replyToGroup} initialReplyAll={true} />)
      expect(screen.getByText('testgroup')).toBeInTheDocument()
    })

    it('shows toggle button to switch to individual reply', () => {
      render(<MessageModal {...defaultProps} replyTo={replyToGroup} initialReplyAll={true} />)
      expect(screen.getByRole('button', { name: 'Switch to individual reply' })).toBeInTheDocument()
    })

    it('shows toggle button to switch to reply all', () => {
      render(<MessageModal {...defaultProps} replyTo={replyToGroup} initialReplyAll={false} />)
      expect(screen.getByRole('button', { name: 'Switch to reply all' })).toBeInTheDocument()
    })
  })

  describe('character limit', () => {
    it('updates character count as user types', () => {
      render(<MessageModal {...defaultProps} />)
      const textarea = screen.getByPlaceholderText('Type your message here...')

      // Use fireEvent.change for more reliable state update
      fireEvent.change(textarea, { target: { value: 'Hello' } })

      expect(screen.getByText('5 / 512 characters')).toBeInTheDocument()
    })

    it('disables send button when over character limit', async () => {
      render(<MessageModal {...defaultProps} />)
      const textarea = screen.getByPlaceholderText('Type your message here...')

      // Type more than 512 characters
      const longMessage = 'a'.repeat(520)
      fireEvent.change(textarea, { target: { value: longMessage } })

      const sendButton = screen.getByRole('button', { name: 'Send Message' })
      expect(sendButton).toBeDisabled()
    })
  })

  describe('validation', () => {
    it('shows error when trying to send empty message', async () => {
      const onSend = jest.fn()
      render(<MessageModal {...defaultProps} onSend={onSend} />)

      // Fill recipient but not message
      const recipientInput = screen.getByPlaceholderText('Username or usergroup name')
      fireEvent.change(recipientInput, { target: { value: 'testuser' } })

      const sendButton = screen.getByRole('button', { name: 'Send Message' })
      expect(sendButton).toBeDisabled() // Button should be disabled when message is empty
    })

    it('shows error when trying to send without recipient', async () => {
      const onSend = jest.fn()
      render(<MessageModal {...defaultProps} onSend={onSend} />)

      const textarea = screen.getByPlaceholderText('Type your message here...')
      fireEvent.change(textarea, { target: { value: 'Hello world' } })

      const sendButton = screen.getByRole('button', { name: 'Send Message' })
      fireEvent.click(sendButton)

      await waitFor(() => {
        expect(screen.getByText('Please specify a recipient')).toBeInTheDocument()
      })
      expect(onSend).not.toHaveBeenCalled()
    })
  })

  describe('sending messages', () => {
    it('calls onSend with recipient and message', async () => {
      const onSend = jest.fn().mockResolvedValue(true)
      render(<MessageModal {...defaultProps} onSend={onSend} />)

      const recipientInput = screen.getByPlaceholderText('Username or usergroup name')
      const textarea = screen.getByPlaceholderText('Type your message here...')

      fireEvent.change(recipientInput, { target: { value: 'testuser' } })
      fireEvent.change(textarea, { target: { value: 'Hello world' } })

      const sendButton = screen.getByRole('button', { name: 'Send Message' })
      fireEvent.click(sendButton)

      await waitFor(() => {
        expect(onSend).toHaveBeenCalledWith('testuser', 'Hello world')
      })
    })

    it('shows "Sending..." while sending', async () => {
      const onSend = jest.fn().mockImplementation(() => new Promise(resolve => setTimeout(() => resolve(true), 100)))
      render(<MessageModal {...defaultProps} onSend={onSend} />)

      const recipientInput = screen.getByPlaceholderText('Username or usergroup name')
      const textarea = screen.getByPlaceholderText('Type your message here...')

      fireEvent.change(recipientInput, { target: { value: 'testuser' } })
      fireEvent.change(textarea, { target: { value: 'Hello' } })

      const sendButton = screen.getByRole('button', { name: 'Send Message' })
      fireEvent.click(sendButton)

      expect(screen.getByRole('button', { name: 'Sending...' })).toBeInTheDocument()
    })

    it('closes modal on successful send', async () => {
      const onSend = jest.fn().mockResolvedValue(true)
      const onClose = jest.fn()
      render(<MessageModal {...defaultProps} onSend={onSend} onClose={onClose} />)

      const recipientInput = screen.getByPlaceholderText('Username or usergroup name')
      const textarea = screen.getByPlaceholderText('Type your message here...')

      fireEvent.change(recipientInput, { target: { value: 'testuser' } })
      fireEvent.change(textarea, { target: { value: 'Hello' } })

      fireEvent.click(screen.getByRole('button', { name: 'Send Message' }))

      await waitFor(() => {
        expect(onClose).toHaveBeenCalled()
      })
    })

    it('shows error message on failed send', async () => {
      const onSend = jest.fn().mockResolvedValue(false)
      render(<MessageModal {...defaultProps} onSend={onSend} />)

      const recipientInput = screen.getByPlaceholderText('Username or usergroup name')
      const textarea = screen.getByPlaceholderText('Type your message here...')

      fireEvent.change(recipientInput, { target: { value: 'testuser' } })
      fireEvent.change(textarea, { target: { value: 'Hello' } })

      fireEvent.click(screen.getByRole('button', { name: 'Send Message' }))

      await waitFor(() => {
        expect(screen.getByText('Failed to send message. Please try again.')).toBeInTheDocument()
      })
    })

    it('shows warning message when present in response', async () => {
      const onSend = jest.fn().mockResolvedValue({ success: true, warning: 'Some users could not be reached' })
      render(<MessageModal {...defaultProps} onSend={onSend} />)

      const recipientInput = screen.getByPlaceholderText('Username or usergroup name')
      const textarea = screen.getByPlaceholderText('Type your message here...')

      fireEvent.change(recipientInput, { target: { value: 'testuser' } })
      fireEvent.change(textarea, { target: { value: 'Hello' } })

      fireEvent.click(screen.getByRole('button', { name: 'Send Message' }))

      await waitFor(() => {
        expect(screen.getByText('Some users could not be reached')).toBeInTheDocument()
      })
    })
  })

  describe('cancel behavior', () => {
    it('calls onClose when Cancel button is clicked', () => {
      const onClose = jest.fn()
      render(<MessageModal {...defaultProps} onClose={onClose} />)

      fireEvent.click(screen.getByRole('button', { name: 'Cancel' }))

      expect(onClose).toHaveBeenCalled()
    })

    it('calls onClose when X button is clicked', () => {
      const onClose = jest.fn()
      render(<MessageModal {...defaultProps} onClose={onClose} />)

      fireEvent.click(screen.getByRole('button', { name: '×' }))

      expect(onClose).toHaveBeenCalled()
    })

    it('does not close when clicking backdrop (for usability)', () => {
      const onClose = jest.fn()
      render(<MessageModal {...defaultProps} onClose={onClose} />)

      // Click the backdrop (outer div) - should NOT close modal
      const modal = screen.getByRole('heading', { name: 'New Message' }).closest('div[style*="position: fixed"]')
      fireEvent.click(modal)

      expect(onClose).not.toHaveBeenCalled()
    })

    it('does not close when clicking modal content', () => {
      const onClose = jest.fn()
      render(<MessageModal {...defaultProps} onClose={onClose} />)

      // Click the modal content
      const modalContent = screen.getByRole('heading', { name: 'New Message' }).closest('div[style*="background-color: rgb(255, 255, 255)"]')
      fireEvent.click(modalContent)

      expect(onClose).not.toHaveBeenCalled()
    })
  })

  describe('initial message', () => {
    it('pre-populates message field with initialMessage prop', () => {
      const initialMsg = 're: Test Node\n\n'
      render(<MessageModal {...defaultProps} initialMessage={initialMsg} />)

      const textarea = screen.getByPlaceholderText('Type your message here...')
      expect(textarea.value).toBe(initialMsg)
    })

    it('shows correct character count with initialMessage', () => {
      const initialMsg = 're: Test Node\n\n'
      render(<MessageModal {...defaultProps} initialMessage={initialMsg} />)

      // "re: Test Node\n\n" is 16 characters
      expect(screen.getByText(`${initialMsg.length} / 512 characters`)).toBeInTheDocument()
    })

    it('clears initialMessage when modal is closed and reopened without it', () => {
      const initialMsg = 're: Test Node\n\n'
      const { rerender } = render(<MessageModal {...defaultProps} initialMessage={initialMsg} />)

      let textarea = screen.getByPlaceholderText('Type your message here...')
      expect(textarea.value).toBe(initialMsg)

      // Close and reopen without initialMessage
      rerender(<MessageModal {...defaultProps} isOpen={false} />)
      rerender(<MessageModal {...defaultProps} isOpen={true} initialMessage="" />)

      textarea = screen.getByPlaceholderText('Type your message here...')
      expect(textarea.value).toBe('')
    })
  })

  describe('send-as bot functionality', () => {
    const botProps = {
      ...defaultProps,
      currentUser: { node_id: 100, title: 'currentuser' },
      accessibleBots: [
        { node_id: 200, title: 'TestBot' },
        { node_id: 300, title: 'AnotherBot' }
      ],
      onSendAsChange: jest.fn()
    }

    it('shows send-as selector when user has accessible bots', () => {
      render(<MessageModal {...botProps} />)
      expect(screen.getByText('Send as:')).toBeInTheDocument()
    })

    it('does not show send-as selector when no bots available', () => {
      render(<MessageModal {...defaultProps} currentUser={{ node_id: 100, title: 'user' }} accessibleBots={[]} />)
      expect(screen.queryByText('Send as:')).not.toBeInTheDocument()
    })

    it('includes current user in send-as options', () => {
      render(<MessageModal {...botProps} />)
      expect(screen.getByText('currentuser (yourself)')).toBeInTheDocument()
    })

    it('includes bots in send-as options', () => {
      render(<MessageModal {...botProps} />)
      expect(screen.getByText('TestBot')).toBeInTheDocument()
      expect(screen.getByText('AnotherBot')).toBeInTheDocument()
    })

    it('calls onSendAsChange when selection changes', () => {
      const onSendAsChange = jest.fn()
      render(<MessageModal {...botProps} onSendAsChange={onSendAsChange} />)

      const select = screen.getByRole('combobox')
      fireEvent.change(select, { target: { value: '200' } })

      expect(onSendAsChange).toHaveBeenCalledWith(200)
    })

    it('shows "Sending as bot" indicator when bot is selected', () => {
      render(<MessageModal {...botProps} sendAsUser={200} />)
      expect(screen.getByText('Sending as bot')).toBeInTheDocument()
    })
  })
})
