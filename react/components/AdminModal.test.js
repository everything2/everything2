import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import AdminModal from './AdminModal'

// Mock fetch globally
global.fetch = jest.fn()

describe('AdminModal', () => {
  const mockWriteup = {
    node_id: 123,
    title: 'Test Writeup',
    author: { node_id: 456, title: 'testauthor' },
    insured: false,
    notnew: false
  }

  const mockEditorUser = {
    node_id: 789,
    title: 'testeditor',
    is_editor: true,
    is_admin: false
  }

  const mockAuthorUser = {
    node_id: 456,
    title: 'testauthor',
    is_editor: false,
    is_admin: false
  }

  const mockAdminUser = {
    node_id: 999,
    title: 'testadmin',
    is_editor: true,
    is_admin: true
  }

  const defaultProps = {
    writeup: mockWriteup,
    user: mockEditorUser,
    isOpen: true,
    onClose: jest.fn()
  }

  beforeEach(() => {
    jest.clearAllMocks()
    fetch.mockClear()
    // Mock window.location.reload
    delete window.location
    window.location = { reload: jest.fn() }
  })

  describe('visibility', () => {
    it('renders nothing when isOpen is false', () => {
      const { container } = render(<AdminModal {...defaultProps} isOpen={false} />)
      expect(container).toBeEmptyDOMElement()
    })

    it('renders nothing when writeup is null', () => {
      const { container } = render(<AdminModal {...defaultProps} writeup={null} />)
      expect(container).toBeEmptyDOMElement()
    })

    it('renders modal when isOpen is true and writeup exists', () => {
      render(<AdminModal {...defaultProps} />)
      expect(screen.getByText('Writeup Tools')).toBeInTheDocument()
    })
  })

  describe('writeup info display', () => {
    it('displays writeup title', () => {
      render(<AdminModal {...defaultProps} />)
      expect(screen.getByText('Test Writeup')).toBeInTheDocument()
    })

    it('displays author name', () => {
      render(<AdminModal {...defaultProps} />)
      expect(screen.getByText('testauthor')).toBeInTheDocument()
    })

    it('shows published status', () => {
      render(<AdminModal {...defaultProps} />)
      expect(screen.getByText(/Status: Published/)).toBeInTheDocument()
    })

    it('shows hidden badge when writeup is hidden', () => {
      render(<AdminModal {...defaultProps} writeup={{ ...mockWriteup, notnew: true }} />)
      expect(screen.getByText(/Hidden/)).toBeInTheDocument()
    })

    it('shows insured badge when writeup is insured', () => {
      render(<AdminModal {...defaultProps} writeup={{ ...mockWriteup, insured: true }} />)
      expect(screen.getByText(/Insured/)).toBeInTheDocument()
    })
  })

  describe('author permissions', () => {
    it('shows edit button for authors', () => {
      render(<AdminModal {...defaultProps} user={mockAuthorUser} />)
      expect(screen.getByText('Edit writeup')).toBeInTheDocument()
    })

    it('shows "Return to drafts" button for authors', () => {
      render(<AdminModal {...defaultProps} user={mockAuthorUser} />)
      expect(screen.getByText('Return to drafts')).toBeInTheDocument()
    })

    it('does not show editor actions for non-editors', () => {
      render(<AdminModal {...defaultProps} user={mockAuthorUser} />)
      expect(screen.queryByText('Editor Actions')).not.toBeInTheDocument()
    })
  })

  describe('editor permissions', () => {
    it('shows editor actions section for editors', () => {
      render(<AdminModal {...defaultProps} user={mockEditorUser} />)
      expect(screen.getByText('Editor Actions')).toBeInTheDocument()
    })

    it('shows hide/unhide button', () => {
      render(<AdminModal {...defaultProps} user={mockEditorUser} />)
      expect(screen.getByText('Hide writeup')).toBeInTheDocument()
    })

    it('shows insure button', () => {
      render(<AdminModal {...defaultProps} user={mockEditorUser} />)
      expect(screen.getByText('Insure writeup')).toBeInTheDocument()
    })

    it('shows reparent link', () => {
      render(<AdminModal {...defaultProps} user={mockEditorUser} />)
      expect(screen.getByText('Reparent writeup...')).toBeInTheDocument()
    })

    it('shows change author link', () => {
      render(<AdminModal {...defaultProps} user={mockEditorUser} />)
      expect(screen.getByText('Change author...')).toBeInTheDocument()
    })

    it('shows removal reason input for editors removing non-authored writeup', () => {
      render(<AdminModal {...defaultProps} user={mockEditorUser} />)
      expect(screen.getByPlaceholderText('Reason for removal')).toBeInTheDocument()
    })
  })

  describe('insured writeups', () => {
    it('does not show remove section for insured writeups', () => {
      render(<AdminModal {...defaultProps} writeup={{ ...mockWriteup, insured: true }} />)
      expect(screen.queryByText('Remove writeup')).not.toBeInTheDocument()
      expect(screen.queryByText('Return to drafts')).not.toBeInTheDocument()
    })

    it('shows "Uninsure writeup" button for insured writeups', () => {
      render(<AdminModal {...defaultProps} writeup={{ ...mockWriteup, insured: true }} />)
      expect(screen.getByText('Uninsure writeup')).toBeInTheDocument()
    })
  })

  describe('hide/unhide action', () => {
    it('calls hide API when clicking hide button', async () => {
      fetch.mockResolvedValueOnce({
        json: () => Promise.resolve({ node_id: 123, notnew: true })
      })

      render(<AdminModal {...defaultProps} />)
      fireEvent.click(screen.getByText('Hide writeup'))

      await waitFor(() => {
        expect(fetch).toHaveBeenCalledWith(
          '/api/hidewriteups/123/action/hide',
          expect.objectContaining({ method: 'POST' })
        )
      })
    })

    it('shows success message after hiding', async () => {
      fetch.mockResolvedValueOnce({
        json: () => Promise.resolve({ node_id: 123, notnew: true })
      })

      render(<AdminModal {...defaultProps} />)
      fireEvent.click(screen.getByText('Hide writeup'))

      await waitFor(() => {
        expect(screen.getByText('Writeup hidden')).toBeInTheDocument()
      })
    })

    it('toggles button text to "Unhide" after hiding', async () => {
      fetch.mockResolvedValueOnce({
        json: () => Promise.resolve({ node_id: 123, notnew: true })
      })

      render(<AdminModal {...defaultProps} />)
      fireEvent.click(screen.getByText('Hide writeup'))

      await waitFor(() => {
        expect(screen.getByText('Unhide writeup')).toBeInTheDocument()
      })
    })
  })

  describe('insure action', () => {
    it('calls insure API when clicking insure button', async () => {
      fetch.mockResolvedValueOnce({
        json: () => Promise.resolve({ success: true, action: 'insured', insured_by: 789 })
      })

      render(<AdminModal {...defaultProps} />)
      fireEvent.click(screen.getByText('Insure writeup'))

      await waitFor(() => {
        expect(fetch).toHaveBeenCalledWith(
          '/api/admin/writeup/123/insure',
          expect.objectContaining({ method: 'POST' })
        )
      })
    })

    it('shows success message after insuring', async () => {
      fetch.mockResolvedValueOnce({
        json: () => Promise.resolve({ success: true, action: 'insured', insured_by: 789 })
      })

      render(<AdminModal {...defaultProps} />)
      fireEvent.click(screen.getByText('Insure writeup'))

      await waitFor(() => {
        expect(screen.getByText('Writeup insured')).toBeInTheDocument()
      })
    })
  })

  describe('remove action', () => {
    it('shows error when editor tries to remove without reason', async () => {
      render(<AdminModal {...defaultProps} />)
      fireEvent.click(screen.getByText('Remove writeup'))

      await waitFor(() => {
        expect(screen.getByText('Please provide a reason for removal')).toBeInTheDocument()
      })
      expect(fetch).not.toHaveBeenCalled()
    })

    it('calls remove API with reason when editor provides one', async () => {
      fetch.mockResolvedValueOnce({
        json: () => Promise.resolve({ success: true })
      })

      render(<AdminModal {...defaultProps} />)

      const reasonInput = screen.getByPlaceholderText('Reason for removal')
      fireEvent.change(reasonInput, { target: { value: 'Duplicate content' } })
      fireEvent.click(screen.getByText('Remove writeup'))

      await waitFor(() => {
        expect(fetch).toHaveBeenCalledWith(
          '/api/admin/writeup/123/remove',
          expect.objectContaining({
            method: 'POST',
            body: JSON.stringify({ reason: 'Duplicate content' })
          })
        )
      })
    })

    it('allows author to remove without reason', async () => {
      fetch.mockResolvedValueOnce({
        json: () => Promise.resolve({ success: true })
      })

      render(<AdminModal {...defaultProps} user={mockAuthorUser} />)
      fireEvent.click(screen.getByText('Return to drafts'))

      await waitFor(() => {
        expect(fetch).toHaveBeenCalled()
      })
    })
  })

  describe('admin tools', () => {
    const writeupWithVote = {
      ...mockWriteup,
      vote: 1,
      cools: [{ node_id: 999, title: 'testadmin' }]
    }

    it('shows admin tools section for admins who have voted', () => {
      render(<AdminModal {...defaultProps} writeup={writeupWithVote} user={mockAdminUser} />)
      expect(screen.getByText('Admin Tools')).toBeInTheDocument()
    })

    it('shows "Remove my vote" button when admin has voted', () => {
      render(<AdminModal {...defaultProps} writeup={writeupWithVote} user={mockAdminUser} />)
      expect(screen.getByText('Remove my vote')).toBeInTheDocument()
    })

    it('shows "Remove my C!" button when admin has cooled', () => {
      render(<AdminModal {...defaultProps} writeup={writeupWithVote} user={mockAdminUser} />)
      expect(screen.getByText('Remove my C!')).toBeInTheDocument()
    })

    it('does not show admin tools for non-admins', () => {
      render(<AdminModal {...defaultProps} writeup={writeupWithVote} user={mockEditorUser} />)
      expect(screen.queryByText('Admin Tools')).not.toBeInTheDocument()
    })
  })

  describe('close behavior', () => {
    it('calls onClose when X button is clicked', () => {
      const onClose = jest.fn()
      render(<AdminModal {...defaultProps} onClose={onClose} />)

      fireEvent.click(screen.getByRole('button', { name: '×' }))

      expect(onClose).toHaveBeenCalled()
    })

    it('calls onClose when clicking backdrop', () => {
      const onClose = jest.fn()
      render(<AdminModal {...defaultProps} onClose={onClose} />)

      // Click the backdrop
      const backdrop = screen.getByText('Writeup Tools').closest('.admin-modal-backdrop')
      fireEvent.click(backdrop)

      expect(onClose).toHaveBeenCalled()
    })

    it('does not close when clicking modal content', () => {
      const onClose = jest.fn()
      render(<AdminModal {...defaultProps} onClose={onClose} />)

      // Click modal content
      const modal = screen.getByText('Writeup Tools').closest('.admin-modal')
      fireEvent.click(modal)

      expect(onClose).not.toHaveBeenCalled()
    })
  })

  describe('onEdit callback', () => {
    it('calls onEdit and closes modal when edit button is clicked with onEdit prop', () => {
      const onEdit = jest.fn()
      const onClose = jest.fn()
      render(<AdminModal {...defaultProps} onEdit={onEdit} onClose={onClose} />)

      fireEvent.click(screen.getByText('Edit writeup'))

      expect(onEdit).toHaveBeenCalled()
      expect(onClose).toHaveBeenCalled()
    })

    it('renders edit link when onEdit is not provided', () => {
      render(<AdminModal {...defaultProps} />)
      const editLink = screen.getByText('Edit writeup')
      expect(editLink).toHaveAttribute('href', '/node/123?edit=1')
    })
  })

  describe('onWriteupUpdate callback', () => {
    it('calls onWriteupUpdate after successful hide action', async () => {
      const onWriteupUpdate = jest.fn()
      fetch.mockResolvedValueOnce({
        json: () => Promise.resolve({ node_id: 123, notnew: true })
      })

      render(<AdminModal {...defaultProps} onWriteupUpdate={onWriteupUpdate} />)
      fireEvent.click(screen.getByText('Hide writeup'))

      await waitFor(() => {
        expect(onWriteupUpdate).toHaveBeenCalledWith(
          expect.objectContaining({ notnew: true })
        )
      })
    })

    it('calls onWriteupUpdate after successful insure action', async () => {
      const onWriteupUpdate = jest.fn()
      fetch.mockResolvedValueOnce({
        json: () => Promise.resolve({ success: true, action: 'insured', insured_by: 789 })
      })

      render(<AdminModal {...defaultProps} onWriteupUpdate={onWriteupUpdate} />)
      fireEvent.click(screen.getByText('Insure writeup'))

      await waitFor(() => {
        expect(onWriteupUpdate).toHaveBeenCalledWith(
          expect.objectContaining({ insured: true, insured_by: 789 })
        )
      })
    })
  })

  describe('error handling', () => {
    it('shows error message when API call fails', async () => {
      fetch.mockRejectedValueOnce(new Error('Network error'))

      render(<AdminModal {...defaultProps} />)
      fireEvent.click(screen.getByText('Hide writeup'))

      await waitFor(() => {
        expect(screen.getByText('Network error')).toBeInTheDocument()
      })
    })

    it('shows error from API response', async () => {
      fetch.mockResolvedValueOnce({
        json: () => Promise.resolve({ error: 'Permission denied' })
      })

      render(<AdminModal {...defaultProps} />)
      fireEvent.click(screen.getByText('Hide writeup'))

      await waitFor(() => {
        expect(screen.getByText('Permission denied')).toBeInTheDocument()
      })
    })
  })
})
