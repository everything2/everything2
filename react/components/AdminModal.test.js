import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import AdminModal from './AdminModal'

// Mock fetch globally
global.fetch = jest.fn()

// Helper to create fetch mock that handles both available groups API and action API
const createFetchMock = (actionResponse) => {
  return jest.fn((url) => {
    if (url === '/api/weblog/available') {
      return Promise.resolve({
        json: () => Promise.resolve({ success: true, groups: [] })
      })
    }
    return Promise.resolve({
      json: () => Promise.resolve(actionResponse)
    })
  })
}

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
    // Default mock for available groups API (called on modal open)
    fetch.mockImplementation((url) => {
      if (url === '/api/weblog/available') {
        return Promise.resolve({
          json: () => Promise.resolve({ success: true, groups: [] })
        })
      }
      // Default for other calls
      return Promise.resolve({
        json: () => Promise.resolve({ success: true })
      })
    })
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
      fetch.mockImplementation((url) => {
        if (url === '/api/weblog/available') {
          return Promise.resolve({
            json: () => Promise.resolve({ success: true, groups: [] })
          })
        }
        return Promise.resolve({
          json: () => Promise.resolve({ node_id: 123, notnew: true })
        })
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
      global.fetch = createFetchMock({ node_id: 123, notnew: true })

      render(<AdminModal {...defaultProps} />)
      fireEvent.click(screen.getByText('Hide writeup'))

      await waitFor(() => {
        expect(screen.getByText('Writeup hidden')).toBeInTheDocument()
      })
    })

    it('toggles button text to "Unhide" after hiding', async () => {
      global.fetch = createFetchMock({ node_id: 123, notnew: true })

      render(<AdminModal {...defaultProps} />)
      fireEvent.click(screen.getByText('Hide writeup'))

      await waitFor(() => {
        expect(screen.getByText('Unhide writeup')).toBeInTheDocument()
      })
    })
  })

  describe('insure action', () => {
    it('calls insure API when clicking insure button', async () => {
      global.fetch = createFetchMock({ success: true, action: 'insured', insured_by: 789 })

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
      global.fetch = createFetchMock({ success: true, action: 'insured', insured_by: 789 })

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
      // Only the available groups API should have been called
      const nonAvailableCalls = fetch.mock.calls.filter(call => call[0] !== '/api/weblog/available')
      expect(nonAvailableCalls).toHaveLength(0)
    })

    it('calls remove API with reason when editor provides one', async () => {
      global.fetch = createFetchMock({ success: true })

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
      global.fetch = createFetchMock({ success: true })

      render(<AdminModal {...defaultProps} user={mockAuthorUser} />)
      fireEvent.click(screen.getByText('Return to drafts'))

      await waitFor(() => {
        const removeCalls = fetch.mock.calls.filter(call => call[0].includes('/remove'))
        expect(removeCalls.length).toBeGreaterThan(0)
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
      global.fetch = createFetchMock({ node_id: 123, notnew: true })

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
      global.fetch = createFetchMock({ success: true, action: 'insured', insured_by: 789 })

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
      global.fetch = jest.fn((url) => {
        if (url === '/api/weblog/available') {
          return Promise.resolve({
            json: () => Promise.resolve({ success: true, groups: [] })
          })
        }
        return Promise.reject(new Error('Network error'))
      })

      render(<AdminModal {...defaultProps} />)
      fireEvent.click(screen.getByText('Hide writeup'))

      await waitFor(() => {
        expect(screen.getByText('Network error')).toBeInTheDocument()
      })
    })

    it('shows error from API response', async () => {
      global.fetch = createFetchMock({ error: 'Permission denied' })

      render(<AdminModal {...defaultProps} />)
      fireEvent.click(screen.getByText('Hide writeup'))

      await waitFor(() => {
        expect(screen.getByText('Permission denied')).toBeInTheDocument()
      })
    })
  })

  describe('post to usergroup', () => {
    const mockGroups = [
      { node_id: 100, title: 'E2science' },
      { node_id: 101, title: 'edev' }
    ]

    it('shows post to usergroup section when groups are available', async () => {
      global.fetch = jest.fn((url) => {
        if (url === '/api/weblog/available') {
          return Promise.resolve({
            json: () => Promise.resolve({ success: true, groups: mockGroups })
          })
        }
        return Promise.resolve({ json: () => Promise.resolve({ success: true }) })
      })

      render(<AdminModal {...defaultProps} />)

      await waitFor(() => {
        expect(screen.getByText('Post to Usergroup')).toBeInTheDocument()
      })
    })

    it('shows loading state while fetching groups', async () => {
      let resolveGroups
      global.fetch = jest.fn((url) => {
        if (url === '/api/weblog/available') {
          return new Promise((resolve) => {
            resolveGroups = () => resolve({
              json: () => Promise.resolve({ success: true, groups: mockGroups })
            })
          })
        }
        return Promise.resolve({ json: () => Promise.resolve({ success: true }) })
      })

      render(<AdminModal {...defaultProps} />)

      expect(screen.getByText('Loading available groups...')).toBeInTheDocument()

      // Resolve the fetch
      resolveGroups()

      await waitFor(() => {
        expect(screen.queryByText('Loading available groups...')).not.toBeInTheDocument()
      })
    })

    it('shows usergroup dropdown with available groups', async () => {
      global.fetch = jest.fn((url) => {
        if (url === '/api/weblog/available') {
          return Promise.resolve({
            json: () => Promise.resolve({ success: true, groups: mockGroups })
          })
        }
        return Promise.resolve({ json: () => Promise.resolve({ success: true }) })
      })

      render(<AdminModal {...defaultProps} />)

      await waitFor(() => {
        expect(screen.getByText('E2science')).toBeInTheDocument()
        expect(screen.getByText('edev')).toBeInTheDocument()
      })
    })

    it('does not show post to usergroup for guests', async () => {
      const guestUser = { ...mockEditorUser, is_guest: true }

      render(<AdminModal {...defaultProps} user={guestUser} />)

      // Wait for potential async operations
      await new Promise(r => setTimeout(r, 100))

      expect(screen.queryByText('Post to Usergroup')).not.toBeInTheDocument()
    })

    it('calls weblog API when posting to usergroup', async () => {
      global.fetch = jest.fn((url, options) => {
        if (url === '/api/weblog/available') {
          return Promise.resolve({
            json: () => Promise.resolve({ success: true, groups: mockGroups })
          })
        }
        if (url === '/api/weblog/100' && options?.method === 'POST') {
          return Promise.resolve({
            json: () => Promise.resolve({ success: true, message: 'Entry added to weblog' })
          })
        }
        return Promise.resolve({ json: () => Promise.resolve({ success: true }) })
      })

      render(<AdminModal {...defaultProps} />)

      await waitFor(() => {
        expect(screen.getByText('E2science')).toBeInTheDocument()
      })

      // Select a usergroup
      const select = screen.getByRole('combobox')
      fireEvent.change(select, { target: { value: '100' } })

      // Click post button
      fireEvent.click(screen.getByText('Post to usergroup'))

      await waitFor(() => {
        expect(fetch).toHaveBeenCalledWith(
          '/api/weblog/100',
          expect.objectContaining({
            method: 'POST',
            body: JSON.stringify({ to_node: 123 })
          })
        )
      })
    })

    it('shows success message after posting to usergroup', async () => {
      global.fetch = jest.fn((url, options) => {
        if (url === '/api/weblog/available') {
          return Promise.resolve({
            json: () => Promise.resolve({ success: true, groups: mockGroups })
          })
        }
        if (url.startsWith('/api/weblog/') && options?.method === 'POST') {
          return Promise.resolve({
            json: () => Promise.resolve({ success: true, message: 'Entry added to weblog' })
          })
        }
        return Promise.resolve({ json: () => Promise.resolve({ success: true }) })
      })

      render(<AdminModal {...defaultProps} />)

      await waitFor(() => {
        expect(screen.getByText('E2science')).toBeInTheDocument()
      })

      const select = screen.getByRole('combobox')
      fireEvent.change(select, { target: { value: '100' } })
      fireEvent.click(screen.getByText('Post to usergroup'))

      await waitFor(() => {
        expect(screen.getByText('Posted to E2science')).toBeInTheDocument()
      })
    })

    it('uses availableGroups prop if provided instead of fetching', async () => {
      render(<AdminModal {...defaultProps} availableGroups={mockGroups} />)

      // Should show groups immediately without loading
      expect(screen.queryByText('Loading available groups...')).not.toBeInTheDocument()
      expect(screen.getByText('E2science')).toBeInTheDocument()
      expect(screen.getByText('edev')).toBeInTheDocument()

      // Should not have called the available groups API
      expect(fetch).not.toHaveBeenCalledWith('/api/weblog/available')
    })
  })
})
