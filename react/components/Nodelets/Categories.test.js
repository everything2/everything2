import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import '@testing-library/jest-dom'
import Categories from './Categories'

// Mock fetch
global.fetch = jest.fn()

// Mock the child components
jest.mock('../NodeletContainer', () => {
  return function MockNodeletContainer({ title, children }) {
    return (
      <div data-testid="nodelet-container">
        <div data-testid="nodelet-title">{title}</div>
        <div data-testid="nodelet-content">{children}</div>
      </div>
    )
  }
})

jest.mock('../LinkNode', () => {
  return function MockLinkNode({ nodeId, title, type, display }) {
    const displayText = display || title || `Node ${nodeId}`
    return (
      <a
        data-testid="link-node"
        data-node-id={nodeId}
        data-title={title}
        data-type={type}
        data-display={display}
      >
        {displayText}
      </a>
    )
  }
})

jest.mock('../ConfirmModal', () => {
  return function MockConfirmModal({ isOpen, onClose, onConfirm, title, message }) {
    if (!isOpen) return null
    return (
      <div data-testid="confirm-modal">
        <div data-testid="confirm-title">{title}</div>
        <div data-testid="confirm-message">{message}</div>
        <button data-testid="confirm-button" onClick={onConfirm}>Confirm</button>
        <button data-testid="cancel-button" onClick={onClose}>Cancel</button>
      </div>
    )
  }
})

describe('Categories', () => {
  const mockNodeCategories = [
    {
      node_id: 101,
      title: 'Science Fiction',
      author_user: 201,
      author_username: 'scifiguy',
      is_public: 0,
      can_remove: 1
    },
    {
      node_id: 102,
      title: 'Fantasy',
      author_user: 202,
      author_username: 'fantasyfan',
      is_public: 0,
      can_remove: 1
    },
    {
      node_id: 103,
      title: 'Public Category',
      author_user: 779713,
      author_username: 'Guest User',
      is_public: 1,
      can_remove: 0
    }
  ]

  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('Rendering', () => {
    test('renders nodelet container with title', () => {
      render(<Categories nodeCategories={mockNodeCategories} currentNodeId={100} />)
      expect(screen.getByTestId('nodelet-title')).toHaveTextContent('Categories')
    })

    test('renders all current categories', () => {
      render(<Categories nodeCategories={mockNodeCategories} currentNodeId={100} />)
      expect(screen.getByText(/Science Fiction/)).toBeInTheDocument()
      expect(screen.getByText(/Fantasy/)).toBeInTheDocument()
      expect(screen.getByText(/Public Category/)).toBeInTheDocument()
    })

    test('renders "In Categories" header when categories exist', () => {
      render(<Categories nodeCategories={mockNodeCategories} currentNodeId={100} />)
      expect(screen.getByText(/In Categories/)).toBeInTheDocument()
    })

    test('renders Add to category button', () => {
      render(<Categories nodeCategories={mockNodeCategories} currentNodeId={100} />)
      expect(screen.getByText(/Add to category/)).toBeInTheDocument()
    })

    test('renders Create category link in footer', () => {
      render(<Categories nodeCategories={mockNodeCategories} currentNodeId={100} />)
      const links = screen.getAllByTestId('link-node')
      const createLink = links.find(link => link.getAttribute('data-title') === 'Create category')
      expect(createLink).toBeDefined()
      expect(createLink).toHaveAttribute('data-type', 'superdoc')
    })
  })

  describe('Empty States', () => {
    test('renders "Not in any categories" when nodeCategories is empty', () => {
      render(<Categories nodeCategories={[]} currentNodeId={100} />)
      expect(screen.getByText(/Not in any categories/i)).toBeInTheDocument()
    })

    test('still shows Add to category button when empty', () => {
      render(<Categories nodeCategories={[]} currentNodeId={100} />)
      expect(screen.getByText(/Add to category/)).toBeInTheDocument()
    })

    test('renders nodelet container when empty', () => {
      render(<Categories nodeCategories={[]} currentNodeId={100} />)
      expect(screen.getByTestId('nodelet-container')).toBeInTheDocument()
      expect(screen.getByTestId('nodelet-title')).toHaveTextContent('Categories')
    })
  })

  describe('Remove Functionality', () => {
    test('shows remove button for categories user can remove', () => {
      const { container } = render(<Categories nodeCategories={mockNodeCategories} currentNodeId={100} />)
      // Categories with can_remove=1 should have remove buttons
      const removeButtons = container.querySelectorAll('button[title="Remove from category"]')
      expect(removeButtons.length).toBe(2) // Science Fiction and Fantasy
    })

    test('does not show remove button for public categories', () => {
      const publicOnly = [{
        node_id: 103,
        title: 'Public Category',
        author_user: 779713,
        author_username: 'Guest User',
        is_public: 1,
        can_remove: 0
      }]
      const { container } = render(<Categories nodeCategories={publicOnly} currentNodeId={100} />)
      const removeButtons = container.querySelectorAll('button[title="Remove from category"]')
      expect(removeButtons.length).toBe(0)
    })

    test('clicking remove button opens confirm modal', () => {
      const { container } = render(<Categories nodeCategories={mockNodeCategories} currentNodeId={100} />)
      const removeButton = container.querySelector('button[title="Remove from category"]')
      fireEvent.click(removeButton)
      expect(screen.getByTestId('confirm-modal')).toBeInTheDocument()
      expect(screen.getByTestId('confirm-title')).toHaveTextContent('Remove from Category')
    })

    test('confirm modal shows category name', () => {
      const { container } = render(<Categories nodeCategories={mockNodeCategories} currentNodeId={100} />)
      const removeButton = container.querySelector('button[title="Remove from category"]')
      fireEvent.click(removeButton)
      expect(screen.getByTestId('confirm-message')).toHaveTextContent(/Science Fiction/)
    })

    test('canceling confirm modal closes it', () => {
      const { container } = render(<Categories nodeCategories={mockNodeCategories} currentNodeId={100} />)
      const removeButton = container.querySelector('button[title="Remove from category"]')
      fireEvent.click(removeButton)
      expect(screen.getByTestId('confirm-modal')).toBeInTheDocument()

      fireEvent.click(screen.getByTestId('cancel-button'))
      expect(screen.queryByTestId('confirm-modal')).not.toBeInTheDocument()
    })
  })

  describe('Add to Category Modal', () => {
    test('clicking Add to category opens modal', () => {
      render(<Categories nodeCategories={mockNodeCategories} currentNodeId={100} />)
      const addButton = screen.getByText(/Add to category/)
      fireEvent.click(addButton)
      expect(screen.getByText('Add to Category')).toBeInTheDocument()
    })

    test('modal loads categories on open', async () => {
      global.fetch.mockResolvedValueOnce({
        json: () => Promise.resolve({
          success: 1,
          your_categories: [{ node_id: 200, title: 'My Category', author_user: 100, author_username: 'me' }],
          public_categories: [{ node_id: 201, title: 'Public Cat', author_user: 779713, author_username: 'Guest User' }],
          other_categories: [],
          is_editor: 0
        })
      })

      render(<Categories nodeCategories={[]} currentNodeId={100} />)
      const addButton = screen.getByText(/Add to category/)
      fireEvent.click(addButton)

      await waitFor(() => {
        expect(global.fetch).toHaveBeenCalledWith(
          '/api/category/list?node_id=100',
          expect.any(Object)
        )
      })
    })

    test('modal shows loading state while fetching', () => {
      global.fetch.mockImplementation(() => new Promise(() => {})) // Never resolves

      render(<Categories nodeCategories={[]} currentNodeId={100} />)
      const addButton = screen.getByText(/Add to category/)
      fireEvent.click(addButton)

      expect(screen.getByText(/Loading categories/)).toBeInTheDocument()
    })

    test('ESC key closes modal', async () => {
      global.fetch.mockResolvedValueOnce({
        json: () => Promise.resolve({
          success: 1,
          your_categories: [],
          public_categories: [],
          other_categories: [],
          is_editor: 0
        })
      })

      render(<Categories nodeCategories={[]} currentNodeId={100} />)
      const addButton = screen.getByText(/Add to category/)
      fireEvent.click(addButton)

      // Wait for modal to be fully rendered
      await waitFor(() => {
        expect(screen.getByText('Add to Category')).toBeInTheDocument()
      })

      fireEvent.keyDown(document, { key: 'Escape' })

      await waitFor(() => {
        expect(screen.queryByText('Add to Category')).not.toBeInTheDocument()
      })
    })
  })

  describe('Search Filter', () => {
    test('search input filters categories', async () => {
      global.fetch.mockResolvedValueOnce({
        json: () => Promise.resolve({
          success: 1,
          your_categories: [
            { node_id: 200, title: 'Science Fiction', author_user: 100, author_username: 'me' },
            { node_id: 201, title: 'Mystery Books', author_user: 100, author_username: 'me' }
          ],
          public_categories: [],
          other_categories: [],
          is_editor: 0
        })
      })

      render(<Categories nodeCategories={[]} currentNodeId={100} />)
      const addButton = screen.getByText(/Add to category/)
      fireEvent.click(addButton)

      await waitFor(() => {
        expect(screen.getByText('Science Fiction')).toBeInTheDocument()
        expect(screen.getByText('Mystery Books')).toBeInTheDocument()
      })

      const searchInput = screen.getByPlaceholderText(/Search categories/)
      fireEvent.change(searchInput, { target: { value: 'Science' } })

      expect(screen.getByText('Science Fiction')).toBeInTheDocument()
      expect(screen.queryByText('Mystery Books')).not.toBeInTheDocument()
    })
  })

  describe('Editor Features', () => {
    test('editors see other users categories', async () => {
      global.fetch.mockResolvedValueOnce({
        json: () => Promise.resolve({
          success: 1,
          your_categories: [],
          public_categories: [],
          other_categories: [
            { node_id: 300, title: 'Other User Cat', author_user: 999, author_username: 'otheruser' }
          ],
          is_editor: 1
        })
      })

      render(<Categories nodeCategories={[]} currentNodeId={100} />)
      const addButton = screen.getByText(/Add to category/)
      fireEvent.click(addButton)

      await waitFor(() => {
        expect(screen.getByText(/Other Users' Categories/)).toBeInTheDocument()
        expect(screen.getByText('Other User Cat')).toBeInTheDocument()
        expect(screen.getByText(/by otheruser/)).toBeInTheDocument()
      })
    })
  })

  describe('Edge Cases', () => {
    test('handles very long category title', () => {
      const longTitle = 'A'.repeat(200)
      const categoriesWithLongTitle = [{
        node_id: 101,
        title: longTitle,
        author_user: 201,
        author_username: 'testuser',
        is_public: 0,
        can_remove: 1
      }]
      render(<Categories nodeCategories={categoriesWithLongTitle} currentNodeId={100} />)
      expect(screen.getByText(new RegExp(longTitle.substring(0, 50)))).toBeInTheDocument()
    })

    test('handles special characters in category title', () => {
      const specialCategories = [{
        node_id: 101,
        title: 'C++ & Programming <tricks>',
        author_user: 201,
        author_username: 'coder',
        is_public: 0,
        can_remove: 1
      }]
      render(<Categories nodeCategories={specialCategories} currentNodeId={100} />)
      expect(screen.getByText(/C\+\+ & Programming/)).toBeInTheDocument()
    })

    test('handles zero node IDs', () => {
      const zeroIdCategories = [{
        node_id: 0,
        title: 'Zero Category',
        author_user: 0,
        author_username: 'root',
        is_public: 0,
        can_remove: 1
      }]
      render(<Categories nodeCategories={zeroIdCategories} currentNodeId={0} />)
      expect(screen.getByText(/Zero Category/)).toBeInTheDocument()
    })
  })

  describe('API Integration', () => {
    test('calls updateNodeCategories after successful remove', async () => {
      const mockUpdate = jest.fn()
      global.fetch.mockResolvedValueOnce({
        json: () => Promise.resolve({ success: 1 })
      })

      const { container } = render(
        <Categories
          nodeCategories={mockNodeCategories}
          currentNodeId={100}
          updateNodeCategories={mockUpdate}
        />
      )

      const removeButton = container.querySelector('button[title="Remove from category"]')
      fireEvent.click(removeButton)
      fireEvent.click(screen.getByTestId('confirm-button'))

      await waitFor(() => {
        expect(mockUpdate).toHaveBeenCalled()
      })
    })

    test('handles API error gracefully', async () => {
      const alertMock = jest.spyOn(window, 'alert').mockImplementation(() => {})
      global.fetch.mockResolvedValueOnce({
        json: () => Promise.resolve({ success: 0, error: 'Server error' })
      })

      const { container } = render(
        <Categories
          nodeCategories={mockNodeCategories}
          currentNodeId={100}
          updateNodeCategories={jest.fn()}
        />
      )

      const removeButton = container.querySelector('button[title="Remove from category"]')
      fireEvent.click(removeButton)
      fireEvent.click(screen.getByTestId('confirm-button'))

      await waitFor(() => {
        expect(alertMock).toHaveBeenCalledWith('Server error')
      })

      alertMock.mockRestore()
    })
  })
})
