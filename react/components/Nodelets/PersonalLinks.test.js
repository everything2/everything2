import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import PersonalLinks from './PersonalLinks'

// Mock child components
jest.mock('../NodeletContainer', () => {
  return function NodeletContainer({ title, children }) {
    return (
      <div data-testid="nodelet-container">
        <h3>{title}</h3>
        {children}
      </div>
    )
  }
})

jest.mock('../LinkNode', () => {
  return function LinkNode({ nodeTitle, title, nodeId, params, className }) {
    const displayText = title || nodeTitle || `Node ${nodeId}`
    return <a data-testid="link-node" className={className}>{displayText}</a>
  }
})

describe('PersonalLinks', () => {
  const mockProps = {
    personalLinks: ['Everything FAQ', 'Cool Archive', 'Writeup Archive'],
    canAddCurrent: true,
    currentNodeId: 12345,
    currentNodeTitle: 'Test Node',
    isGuest: false,
    verifyHash: { op_verify: 'abc123' },
    showNodelet: jest.fn(),
    nodeletIsOpen: true
  }

  test('renders personal links list', () => {
    render(<PersonalLinks {...mockProps} />)

    expect(screen.getByText('Everything FAQ')).toBeInTheDocument()
    expect(screen.getByText('Cool Archive')).toBeInTheDocument()
    expect(screen.getByText('Writeup Archive')).toBeInTheDocument()
  })

  test('shows "add current" link when canAddCurrent is true', () => {
    render(<PersonalLinks {...mockProps} />)

    const addLinks = screen.getAllByText('add "Test Node"')
    expect(addLinks.length).toBeGreaterThan(0)
  })

  test('hides "add current" link when no current node title', () => {
    const props = { ...mockProps, currentNodeTitle: '' }
    render(<PersonalLinks {...props} />)

    expect(screen.queryByText(/^add "/)).not.toBeInTheDocument()
  })

  test('does not show Nodelet Settings link (removed as redundant)', () => {
    render(<PersonalLinks {...mockProps} />)

    expect(screen.queryByText('Nodelet Settings')).not.toBeInTheDocument()
  })

  test('shows guest message when isGuest is true', () => {
    const props = { ...mockProps, isGuest: true }
    render(<PersonalLinks {...props} />)

    expect(screen.getByText('You must log in first.')).toBeInTheDocument()
    expect(screen.queryByText('Everything FAQ')).not.toBeInTheDocument()
  })

  test('shows empty state when personalLinks is empty array', () => {
    const props = { ...mockProps, personalLinks: [] }
    render(<PersonalLinks {...props} />)

    expect(screen.queryByText('Everything FAQ')).not.toBeInTheDocument()
    // Should show add button if canAddCurrent is true
    expect(screen.getByText('add "Test Node"')).toBeInTheDocument()
  })

  test('shows empty state when personalLinks is undefined', () => {
    const props = { ...mockProps, personalLinks: undefined }
    render(<PersonalLinks {...props} />)

    // Should show add button if canAddCurrent is true
    expect(screen.getByText('add "Test Node"')).toBeInTheDocument()
  })

  test('shows empty state when personalLinks is not an array', () => {
    const props = { ...mockProps, personalLinks: 'not an array' }
    render(<PersonalLinks {...props} />)

    // Should show add button if canAddCurrent is true
    expect(screen.getByText('add "Test Node"')).toBeInTheDocument()
  })

  describe('API functionality', () => {
    beforeEach(() => {
      global.fetch = jest.fn()
      delete window.location
      window.location = { reload: jest.fn() }
    })

    afterEach(() => {
      jest.restoreAllMocks()
    })

    test('clicking add current makes API call', async () => {
      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          links: ['Everything FAQ', 'Cool Archive', 'Writeup Archive', 'Test Node'],
          count: 4,
          total_chars: 100,
          item_limit: 20,
          char_limit: 1000
        })
      })

      render(<PersonalLinks {...mockProps} />)

      const addLink = screen.getAllByText('add "Test Node"')[0]
      fireEvent.click(addLink)

      await waitFor(() => {
        expect(global.fetch).toHaveBeenCalledWith(
          '/api/personallinks/add',
          expect.objectContaining({
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({ title: 'Test Node' }),
            credentials: 'include',
          })
        )
      })
    })

    test('shows loading state while adding', async () => {
      global.fetch.mockImplementationOnce(() => new Promise(resolve => setTimeout(resolve, 100)))

      render(<PersonalLinks {...mockProps} />)

      const addLink = screen.getAllByText('add "Test Node"')[0]
      fireEvent.click(addLink)

      expect(screen.getByText('adding...')).toBeInTheDocument()
    })

    test('updates state on successful add without page reload', async () => {
      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          links: ['Everything FAQ', 'Cool Archive', 'Writeup Archive', 'Test Node'],
          count: 4,
          total_chars: 100,
          item_limit: 20,
          char_limit: 1000
        })
      })

      render(<PersonalLinks {...mockProps} />)

      const addLink = screen.getAllByText('add "Test Node"')[0]
      fireEvent.click(addLink)

      await waitFor(() => {
        // Should not reload page
        expect(window.location.reload).not.toHaveBeenCalled()
        // Should show the new link in the list
        expect(screen.getAllByTestId('link-node')).toHaveLength(4)
      })
    })

    test('shows error message on API failure', async () => {
      global.fetch.mockResolvedValueOnce({
        ok: false,
        json: async () => ({ error: 'Cannot add more links' })
      })

      render(<PersonalLinks {...mockProps} />)

      const addLink = screen.getAllByText('add "Test Node"')[0]
      fireEvent.click(addLink)

      await waitFor(() => {
        expect(screen.getByText('Cannot add more links')).toBeInTheDocument()
      })
    })

    test('shows generic error on network failure', async () => {
      global.fetch.mockRejectedValueOnce(new Error('Network error'))

      render(<PersonalLinks {...mockProps} />)

      const addLink = screen.getAllByText('add "Test Node"')[0]
      fireEvent.click(addLink)

      await waitFor(() => {
        expect(screen.getByText('Network error')).toBeInTheDocument()
      })
    })

    test('renders delete button for each link', () => {
      render(<PersonalLinks {...mockProps} />)

      const deleteButtons = screen.getAllByText('[x]')
      expect(deleteButtons).toHaveLength(3)
    })

    test('clicking delete button makes DELETE API call', async () => {
      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          links: ['Everything FAQ', 'Writeup Archive'],
          count: 2,
          total_chars: 50,
          item_limit: 20,
          char_limit: 1000
        })
      })

      render(<PersonalLinks {...mockProps} />)

      const deleteButtons = screen.getAllByText('[x]')
      fireEvent.click(deleteButtons[1]) // Delete second item (index 1)

      await waitFor(() => {
        expect(global.fetch).toHaveBeenCalledWith(
          '/api/personallinks/delete/1',
          expect.objectContaining({
            method: 'DELETE',
            credentials: 'include',
          })
        )
      })
    })

    test('shows loading state while deleting', async () => {
      global.fetch.mockImplementationOnce(() => new Promise(resolve => setTimeout(resolve, 100)))

      render(<PersonalLinks {...mockProps} />)

      const deleteButtons = screen.getAllByText('[x]')
      fireEvent.click(deleteButtons[0])

      expect(screen.getByText('...')).toBeInTheDocument()
    })

    test('updates state on successful delete without page reload', async () => {
      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          links: ['Everything FAQ', 'Writeup Archive'],
          count: 2,
          total_chars: 50,
          item_limit: 20,
          char_limit: 1000
        })
      })

      render(<PersonalLinks {...mockProps} />)

      const deleteButtons = screen.getAllByText('[x]')
      fireEvent.click(deleteButtons[1])

      await waitFor(() => {
        // Should not reload page
        expect(window.location.reload).not.toHaveBeenCalled()
        // Should show only 2 links now
        expect(screen.getAllByTestId('link-node')).toHaveLength(2)
      })
    })

    test('shows error message on delete failure', async () => {
      global.fetch.mockResolvedValueOnce({
        ok: false,
        json: async () => ({ error: 'Failed to delete link' })
      })

      render(<PersonalLinks {...mockProps} />)

      const deleteButtons = screen.getAllByText('[x]')
      fireEvent.click(deleteButtons[0])

      await waitFor(() => {
        expect(screen.getByText('Failed to delete link')).toBeInTheDocument()
      })
    })

    test('shows generic error on delete network failure', async () => {
      global.fetch.mockRejectedValueOnce(new Error('Network error'))

      render(<PersonalLinks {...mockProps} />)

      const deleteButtons = screen.getAllByText('[x]')
      fireEvent.click(deleteButtons[0])

      await waitFor(() => {
        expect(screen.getByText('Network error')).toBeInTheDocument()
      })
    })
  })
})
