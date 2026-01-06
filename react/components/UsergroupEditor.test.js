import React from 'react'
import { render, screen, fireEvent, waitFor, within } from '@testing-library/react'
import UsergroupEditor from './UsergroupEditor'

// Mock fetch globally
global.fetch = jest.fn()

describe('UsergroupEditor', () => {
  const mockUsergroup = {
    node_id: 123,
    title: 'Test Group',
    group: [
      { node_id: 1, title: 'user1', type: 'user', is_owner: true, flags: '@' },
      { node_id: 2, title: 'user2', type: 'user', is_owner: false, flags: '' },
      { node_id: 3, title: 'subgroup1', type: 'usergroup', is_owner: false, flags: '' }
    ]
  }

  const defaultProps = {
    isOpen: true,
    onClose: jest.fn(),
    usergroup: mockUsergroup,
    onUpdate: jest.fn()
  }

  beforeEach(() => {
    jest.clearAllMocks()
    fetch.mockClear()
    // Default mock for search API (uses node_search endpoint now)
    fetch.mockImplementation((url) => {
      if (url.includes('/api/node_search')) {
        return Promise.resolve({
          json: () => Promise.resolve({ success: true, results: [] })
        })
      }
      return Promise.resolve({
        json: () => Promise.resolve({ success: true })
      })
    })
  })

  describe('visibility', () => {
    it('renders nothing when isOpen is false', () => {
      const { container } = render(<UsergroupEditor {...defaultProps} isOpen={false} />)
      expect(container).toBeEmptyDOMElement()
    })

    it('renders modal when isOpen is true', () => {
      render(<UsergroupEditor {...defaultProps} />)
      expect(screen.getByText('Edit Members: Test Group')).toBeInTheDocument()
    })

    it('renders nothing when usergroup is null', () => {
      const { container } = render(<UsergroupEditor {...defaultProps} usergroup={null} />)
      expect(container).toBeEmptyDOMElement()
    })
  })

  describe('member display', () => {
    it('displays all members', () => {
      render(<UsergroupEditor {...defaultProps} />)
      expect(screen.getByText('user1')).toBeInTheDocument()
      expect(screen.getByText('user2')).toBeInTheDocument()
      expect(screen.getByText('subgroup1')).toBeInTheDocument()
    })

    it('shows member count', () => {
      render(<UsergroupEditor {...defaultProps} />)
      expect(screen.getByText('Members (3)')).toBeInTheDocument()
    })

    it('shows owner badge for owner', () => {
      render(<UsergroupEditor {...defaultProps} />)
      expect(screen.getByText('owner')).toBeInTheDocument()
    })

    it('shows empty state when no members', () => {
      render(<UsergroupEditor {...defaultProps} usergroup={{ ...mockUsergroup, group: [] }} />)
      expect(screen.getByText('No members in this group')).toBeInTheDocument()
    })
  })

  describe('close functionality', () => {
    it('calls onClose when close button clicked', () => {
      const onClose = jest.fn()
      render(<UsergroupEditor {...defaultProps} onClose={onClose} />)

      fireEvent.click(screen.getByText('×'))
      expect(onClose).toHaveBeenCalled()
    })

    it('calls onClose when Done button clicked', () => {
      const onClose = jest.fn()
      render(<UsergroupEditor {...defaultProps} onClose={onClose} />)

      fireEvent.click(screen.getByText('Done'))
      expect(onClose).toHaveBeenCalled()
    })

    it('does not close when backdrop clicked (working modal)', () => {
      const onClose = jest.fn()
      render(<UsergroupEditor {...defaultProps} onClose={onClose} />)

      // Click on the backdrop (outermost div) - should NOT close
      const backdrop = document.querySelector('[style*="position: fixed"]')
      fireEvent.click(backdrop)
      expect(onClose).not.toHaveBeenCalled()
    })
  })

  describe('search functionality', () => {
    it('shows search input', () => {
      render(<UsergroupEditor {...defaultProps} />)
      expect(screen.getByPlaceholderText('Search for users or usergroups...')).toBeInTheDocument()
    })

    it('does not search with less than 2 characters', async () => {
      render(<UsergroupEditor {...defaultProps} />)

      const searchInput = screen.getByPlaceholderText('Search for users or usergroups...')
      fireEvent.change(searchInput, { target: { value: 'a' } })

      // Wait a bit to ensure no API call is made
      await new Promise(r => setTimeout(r, 400))
      expect(fetch).not.toHaveBeenCalled()
    })

    it('searches when 2+ characters entered', async () => {
      fetch.mockImplementation((url) => {
        if (url.includes('/api/node_search')) {
          return Promise.resolve({
            json: () => Promise.resolve({
              success: true,
              results: [
                { node_id: 100, title: 'testuser', type: 'user' }
              ]
            })
          })
        }
        return Promise.resolve({ json: () => Promise.resolve({ success: true }) })
      })

      render(<UsergroupEditor {...defaultProps} />)

      const searchInput = screen.getByPlaceholderText('Search for users or usergroups...')
      fireEvent.change(searchInput, { target: { value: 'test' } })

      await waitFor(() => {
        expect(fetch).toHaveBeenCalledWith(expect.stringContaining('/api/node_search?q=test'))
      })

      await waitFor(() => {
        expect(screen.getByText('testuser')).toBeInTheDocument()
      })
    })

    it('shows result type badge', async () => {
      fetch.mockImplementation((url) => {
        if (url.includes('/api/node_search')) {
          return Promise.resolve({
            json: () => Promise.resolve({
              success: true,
              results: [
                { node_id: 100, title: 'testuser', type: 'user' },
                { node_id: 101, title: 'testgroup', type: 'usergroup' }
              ]
            })
          })
        }
        return Promise.resolve({ json: () => Promise.resolve({ success: true }) })
      })

      render(<UsergroupEditor {...defaultProps} />)

      const searchInput = screen.getByPlaceholderText('Search for users or usergroups...')
      fireEvent.change(searchInput, { target: { value: 'test' } })

      await waitFor(() => {
        // Type badges should appear
        expect(screen.getByText('user')).toBeInTheDocument()
        expect(screen.getByText('usergroup')).toBeInTheDocument()
      })
    })
  })

  describe('add member', () => {
    it('calls adduser API when clicking search result', async () => {
      fetch.mockImplementation((url, options) => {
        if (url.includes('/api/node_search')) {
          return Promise.resolve({
            json: () => Promise.resolve({
              success: true,
              results: [{ node_id: 100, title: 'newuser', type: 'user' }]
            })
          })
        }
        if (url.includes('/action/adduser')) {
          return Promise.resolve({
            json: () => Promise.resolve({
              group: [...mockUsergroup.group, { node_id: 100, title: 'newuser', type: 'user' }]
            })
          })
        }
        return Promise.resolve({ json: () => Promise.resolve({ success: true }) })
      })

      const onUpdate = jest.fn()
      render(<UsergroupEditor {...defaultProps} onUpdate={onUpdate} />)

      // Search
      const searchInput = screen.getByPlaceholderText('Search for users or usergroups...')
      fireEvent.change(searchInput, { target: { value: 'newuser' } })

      await waitFor(() => {
        expect(screen.getByText('newuser')).toBeInTheDocument()
      })

      // Click to add
      fireEvent.click(screen.getByText('newuser'))

      await waitFor(() => {
        expect(fetch).toHaveBeenCalledWith(
          '/api/usergroups/123/action/adduser',
          expect.objectContaining({
            method: 'POST',
            body: JSON.stringify([100])
          })
        )
      })

      await waitFor(() => {
        expect(onUpdate).toHaveBeenCalled()
      })
    })

    it('shows success message after adding', async () => {
      fetch.mockImplementation((url) => {
        if (url.includes('/api/node_search')) {
          return Promise.resolve({
            json: () => Promise.resolve({
              success: true,
              results: [{ node_id: 100, title: 'newuser', type: 'user' }]
            })
          })
        }
        if (url.includes('/action/adduser')) {
          return Promise.resolve({
            json: () => Promise.resolve({ group: mockUsergroup.group })
          })
        }
        return Promise.resolve({ json: () => Promise.resolve({ success: true }) })
      })

      render(<UsergroupEditor {...defaultProps} />)

      const searchInput = screen.getByPlaceholderText('Search for users or usergroups...')
      fireEvent.change(searchInput, { target: { value: 'newuser' } })

      await waitFor(() => {
        expect(screen.getByText('newuser')).toBeInTheDocument()
      })

      fireEvent.click(screen.getByText('newuser'))

      await waitFor(() => {
        expect(screen.getByText('Added newuser')).toBeInTheDocument()
      })
    })
  })

  describe('remove member', () => {
    it('calls removeuser API when remove button clicked', async () => {
      fetch.mockImplementation((url) => {
        if (url.includes('/action/removeuser')) {
          return Promise.resolve({
            json: () => Promise.resolve({
              group: [mockUsergroup.group[0], mockUsergroup.group[2]]
            })
          })
        }
        return Promise.resolve({ json: () => Promise.resolve({ success: true, results: [] }) })
      })

      const onUpdate = jest.fn()
      render(<UsergroupEditor {...defaultProps} onUpdate={onUpdate} />)

      // Find remove button for user2 (not owner)
      const removeButtons = screen.getAllByTitle('Remove member')
      expect(removeButtons.length).toBeGreaterThan(0)

      fireEvent.click(removeButtons[0])

      await waitFor(() => {
        expect(fetch).toHaveBeenCalledWith(
          '/api/usergroups/123/action/removeuser',
          expect.objectContaining({ method: 'POST' })
        )
      })
    })

    it('prevents removing owner', () => {
      render(<UsergroupEditor {...defaultProps} />)

      // The owner's remove button should be disabled
      const ownerRemoveBtn = screen.getByTitle('Cannot remove owner')
      expect(ownerRemoveBtn).toBeDisabled()
    })

    it('shows success message after removing', async () => {
      fetch.mockImplementation((url) => {
        if (url.includes('/action/removeuser')) {
          return Promise.resolve({
            json: () => Promise.resolve({ group: [mockUsergroup.group[0]] })
          })
        }
        return Promise.resolve({ json: () => Promise.resolve({ success: true, results: [] }) })
      })

      render(<UsergroupEditor {...defaultProps} />)

      const removeButtons = screen.getAllByTitle('Remove member')
      fireEvent.click(removeButtons[0])

      await waitFor(() => {
        expect(screen.getByText(/Removed/)).toBeInTheDocument()
      })
    })
  })

  describe('reorder functionality', () => {
    // Helper to create mock dataTransfer
    const createMockDataTransfer = () => ({
      setData: jest.fn(),
      effectAllowed: '',
      dropEffect: ''
    })

    it('shows Save Order button after drag-drop reorder', () => {
      render(<UsergroupEditor {...defaultProps} />)

      // Initially no Save Order button
      expect(screen.queryByText('Save Order')).not.toBeInTheDocument()

      // Simulate drag and drop by triggering the events
      const memberItems = document.querySelectorAll('[draggable="true"]')
      expect(memberItems.length).toBe(3)

      // Start drag from first item
      fireEvent.dragStart(memberItems[0], { dataTransfer: createMockDataTransfer() })

      // Drop on second item
      fireEvent.dragOver(memberItems[1], { dataTransfer: createMockDataTransfer() })
      fireEvent.drop(memberItems[1], { dataTransfer: createMockDataTransfer() })
      fireEvent.dragEnd(memberItems[0])

      // Save Order button should appear
      expect(screen.getByText('Save Order')).toBeInTheDocument()
    })

    it('calls reorder API when Save Order clicked', async () => {
      fetch.mockImplementation((url) => {
        if (url.includes('/action/reorder')) {
          return Promise.resolve({
            json: () => Promise.resolve({ success: true, group: mockUsergroup })
          })
        }
        return Promise.resolve({ json: () => Promise.resolve({ success: true, results: [] }) })
      })

      render(<UsergroupEditor {...defaultProps} />)

      // Simulate reorder
      const memberItems = document.querySelectorAll('[draggable="true"]')
      fireEvent.dragStart(memberItems[0], { dataTransfer: createMockDataTransfer() })
      fireEvent.dragOver(memberItems[1], { dataTransfer: createMockDataTransfer() })
      fireEvent.drop(memberItems[1], { dataTransfer: createMockDataTransfer() })
      fireEvent.dragEnd(memberItems[0])

      // Click Save Order
      fireEvent.click(screen.getByText('Save Order'))

      await waitFor(() => {
        expect(fetch).toHaveBeenCalledWith(
          '/api/usergroups/123/action/reorder',
          expect.objectContaining({ method: 'POST' })
        )
      })
    })

    it('shows warning when closing with unsaved changes', () => {
      const confirmSpy = jest.spyOn(window, 'confirm').mockReturnValue(false)
      const onClose = jest.fn()

      render(<UsergroupEditor {...defaultProps} onClose={onClose} />)

      // Simulate reorder to create unsaved changes
      const memberItems = document.querySelectorAll('[draggable="true"]')
      fireEvent.dragStart(memberItems[0], { dataTransfer: createMockDataTransfer() })
      fireEvent.dragOver(memberItems[1], { dataTransfer: createMockDataTransfer() })
      fireEvent.drop(memberItems[1], { dataTransfer: createMockDataTransfer() })
      fireEvent.dragEnd(memberItems[0])

      // Try to close
      fireEvent.click(screen.getByText('Done'))

      expect(confirmSpy).toHaveBeenCalledWith(expect.stringContaining('unsaved changes'))
      expect(onClose).not.toHaveBeenCalled()

      confirmSpy.mockRestore()
    })
  })

  describe('error handling', () => {
    // Helper to create mock dataTransfer
    const createMockDataTransfer = () => ({
      setData: jest.fn(),
      effectAllowed: '',
      dropEffect: ''
    })

    it('shows error when add fails', async () => {
      fetch.mockImplementation((url) => {
        if (url.includes('/api/node_search')) {
          return Promise.resolve({
            json: () => Promise.resolve({
              success: true,
              results: [{ node_id: 100, title: 'newuser', type: 'user' }]
            })
          })
        }
        if (url.includes('/action/adduser')) {
          return Promise.resolve({
            json: () => Promise.resolve({ error: 'Permission denied' })
          })
        }
        return Promise.resolve({ json: () => Promise.resolve({ success: true }) })
      })

      render(<UsergroupEditor {...defaultProps} />)

      const searchInput = screen.getByPlaceholderText('Search for users or usergroups...')
      fireEvent.change(searchInput, { target: { value: 'newuser' } })

      await waitFor(() => {
        expect(screen.getByText('newuser')).toBeInTheDocument()
      })

      fireEvent.click(screen.getByText('newuser'))

      await waitFor(() => {
        expect(screen.getByText('Permission denied')).toBeInTheDocument()
      })
    })

    it('shows error when remove fails', async () => {
      fetch.mockImplementation((url) => {
        if (url.includes('/action/removeuser')) {
          return Promise.resolve({
            json: () => Promise.resolve({ error: 'Cannot remove this user' })
          })
        }
        return Promise.resolve({ json: () => Promise.resolve({ success: true, results: [] }) })
      })

      render(<UsergroupEditor {...defaultProps} />)

      const removeButtons = screen.getAllByTitle('Remove member')
      fireEvent.click(removeButtons[0])

      await waitFor(() => {
        expect(screen.getByText('Cannot remove this user')).toBeInTheDocument()
      })
    })

    it('shows error when reorder fails', async () => {
      fetch.mockImplementation((url) => {
        if (url.includes('/action/reorder')) {
          return Promise.resolve({
            json: () => Promise.resolve({ success: false, error: 'Reorder failed' })
          })
        }
        return Promise.resolve({ json: () => Promise.resolve({ success: true, results: [] }) })
      })

      render(<UsergroupEditor {...defaultProps} />)

      // Simulate reorder
      const memberItems = document.querySelectorAll('[draggable="true"]')
      fireEvent.dragStart(memberItems[0], { dataTransfer: createMockDataTransfer() })
      fireEvent.dragOver(memberItems[1], { dataTransfer: createMockDataTransfer() })
      fireEvent.drop(memberItems[1], { dataTransfer: createMockDataTransfer() })
      fireEvent.dragEnd(memberItems[0])

      fireEvent.click(screen.getByText('Save Order'))

      await waitFor(() => {
        expect(screen.getByText('Reorder failed')).toBeInTheDocument()
      })
    })
  })
})
