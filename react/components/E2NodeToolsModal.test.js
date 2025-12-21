import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import E2NodeToolsModal from './E2NodeToolsModal'

// Mock react-modal
jest.mock('react-modal', () => {
  return function MockModal({ isOpen, children, contentLabel }) {
    if (!isOpen) return null
    return (
      <div data-testid="modal" aria-label={contentLabel}>
        {children}
      </div>
    )
  }
})

// Mock react-icons
jest.mock('react-icons/fa', () => ({
  FaTools: () => <span data-testid="icon-tools">tools</span>,
  FaTimes: () => <span data-testid="icon-times">x</span>,
  FaLink: () => <span data-testid="icon-link">link</span>,
  FaSort: () => <span data-testid="icon-sort">sort</span>,
  FaEdit: () => <span data-testid="icon-edit">edit</span>,
  FaLock: () => <span data-testid="icon-lock">lock</span>,
  FaUnlink: () => <span data-testid="icon-unlink">unlink</span>
}))

// Mock @dnd-kit modules to avoid complex drag-and-drop testing
jest.mock('@dnd-kit/core', () => ({
  DndContext: ({ children }) => <div data-testid="dnd-context">{children}</div>,
  closestCenter: jest.fn(),
  KeyboardSensor: jest.fn(),
  PointerSensor: jest.fn(),
  useSensor: jest.fn(),
  useSensors: jest.fn(() => [])
}))

jest.mock('@dnd-kit/sortable', () => ({
  arrayMove: jest.fn((arr, from, to) => arr),
  SortableContext: ({ children }) => <div data-testid="sortable-context">{children}</div>,
  sortableKeyboardCoordinates: jest.fn(),
  useSortable: jest.fn(() => ({
    attributes: {},
    listeners: {},
    setNodeRef: jest.fn(),
    transform: null,
    transition: null,
    isDragging: false
  })),
  verticalListSortingStrategy: jest.fn()
}))

jest.mock('@dnd-kit/utilities', () => ({
  CSS: { Transform: { toString: jest.fn() } }
}))

// Mock fetch for API calls
global.fetch = jest.fn()

describe('E2NodeToolsModal', () => {
  const mockE2Node = {
    node_id: 123,
    title: 'Test Node',
    firmlinks: [],
    group: []
  }

  const mockEditor = {
    node_id: 456,
    title: 'editoruser',
    editor: true,
    is_editor: true
  }

  const mockNonEditor = {
    node_id: 789,
    title: 'regularuser',
    editor: false,
    is_editor: false
  }

  const mockOnClose = jest.fn()

  beforeEach(() => {
    jest.clearAllMocks()
    fetch.mockClear()
  })

  describe('access control', () => {
    it('returns null for non-editor users', () => {
      const { container } = render(
        <E2NodeToolsModal
          e2node={mockE2Node}
          isOpen={true}
          onClose={mockOnClose}
          user={mockNonEditor}
        />
      )

      expect(container).toBeEmptyDOMElement()
    })

    it('renders modal for editor users', () => {
      render(
        <E2NodeToolsModal
          e2node={mockE2Node}
          isOpen={true}
          onClose={mockOnClose}
          user={mockEditor}
        />
      )

      expect(screen.getByTestId('modal')).toBeInTheDocument()
    })

    it('returns null when modal is closed', () => {
      const { container } = render(
        <E2NodeToolsModal
          e2node={mockE2Node}
          isOpen={false}
          onClose={mockOnClose}
          user={mockEditor}
        />
      )

      expect(container).toBeEmptyDOMElement()
    })
  })

  describe('modal content', () => {
    it('displays the node title', () => {
      render(
        <E2NodeToolsModal
          e2node={mockE2Node}
          isOpen={true}
          onClose={mockOnClose}
          user={mockEditor}
        />
      )

      expect(screen.getByText('Test Node')).toBeInTheDocument()
    })

    it('displays modal header with title', () => {
      render(
        <E2NodeToolsModal
          e2node={mockE2Node}
          isOpen={true}
          onClose={mockOnClose}
          user={mockEditor}
        />
      )

      expect(screen.getByText('E2 Node Tools')).toBeInTheDocument()
    })

    it('has close button', () => {
      render(
        <E2NodeToolsModal
          e2node={mockE2Node}
          isOpen={true}
          onClose={mockOnClose}
          user={mockEditor}
        />
      )

      const closeButton = screen.getByLabelText('Close')
      expect(closeButton).toBeInTheDocument()
    })
  })

  describe('tool menu', () => {
    it('displays all tool menu items', () => {
      render(
        <E2NodeToolsModal
          e2node={mockE2Node}
          isOpen={true}
          onClose={mockOnClose}
          user={mockEditor}
        />
      )

      // Firmlink appears in both menu and submit button - check menu has it
      const menuNav = screen.getByRole('navigation')
      expect(menuNav).toHaveTextContent('Firmlink')
      expect(screen.getByText('Trim Softlinks')).toBeInTheDocument()
      expect(screen.getByText('Order & Repair')).toBeInTheDocument()
      expect(screen.getByText('Title Change')).toBeInTheDocument()
      expect(screen.getByText('Node Lock')).toBeInTheDocument()
    })

    it('starts with Firmlink tool selected', () => {
      render(
        <E2NodeToolsModal
          e2node={mockE2Node}
          isOpen={true}
          onClose={mockOnClose}
          user={mockEditor}
        />
      )

      // Firmlink panel should show by default
      expect(screen.getByText('Create Firmlink')).toBeInTheDocument()
    })

    it('switches to Title Change panel on click', () => {
      render(
        <E2NodeToolsModal
          e2node={mockE2Node}
          isOpen={true}
          onClose={mockOnClose}
          user={mockEditor}
        />
      )

      fireEvent.click(screen.getByText('Title Change'))

      expect(screen.getByText('Change Title')).toBeInTheDocument()
    })

    it('switches to Node Lock panel on click', () => {
      fetch.mockResolvedValueOnce({
        json: () => Promise.resolve({ success: true, lock: null })
      })

      render(
        <E2NodeToolsModal
          e2node={mockE2Node}
          isOpen={true}
          onClose={mockOnClose}
          user={mockEditor}
        />
      )

      fireEvent.click(screen.getByText('Node Lock'))

      expect(screen.getByText('Node Lock', { selector: 'h3' })).toBeInTheDocument()
    })
  })

  describe('Firmlink panel', () => {
    it('displays firmlink form', () => {
      render(
        <E2NodeToolsModal
          e2node={mockE2Node}
          isOpen={true}
          onClose={mockOnClose}
          user={mockEditor}
        />
      )

      expect(screen.getByLabelText('Firmlink node to:')).toBeInTheDocument()
      expect(screen.getByLabelText('With (optional) following text:')).toBeInTheDocument()
      expect(screen.getByRole('button', { name: 'Firmlink' })).toBeInTheDocument()
    })

    it('submits firmlink form', async () => {
      fetch.mockResolvedValueOnce({
        json: () => Promise.resolve({ success: true, message: 'Firmlink created', firmlinks: [] })
      })

      render(
        <E2NodeToolsModal
          e2node={mockE2Node}
          isOpen={true}
          onClose={mockOnClose}
          user={mockEditor}
        />
      )

      fireEvent.change(screen.getByLabelText('Firmlink node to:'), {
        target: { value: 'Target Node' }
      })
      fireEvent.click(screen.getByRole('button', { name: 'Firmlink' }))

      await waitFor(() => {
        expect(fetch).toHaveBeenCalledWith(
          '/api/e2node/123/firmlink',
          expect.objectContaining({
            method: 'POST',
            body: JSON.stringify({ to_node: 'Target Node', note_text: '' })
          })
        )
      })
    })

    it('displays existing firmlinks', () => {
      const e2nodeWithFirmlinks = {
        ...mockE2Node,
        firmlinks: [
          { node_id: 100, title: 'Linked Node', note_text: 'See also' }
        ]
      }

      render(
        <E2NodeToolsModal
          e2node={e2nodeWithFirmlinks}
          isOpen={true}
          onClose={mockOnClose}
          user={mockEditor}
        />
      )

      expect(screen.getByText('Existing Firmlinks')).toBeInTheDocument()
      expect(screen.getByText('Linked Node')).toBeInTheDocument()
    })
  })

  describe('Title Change panel', () => {
    it('displays current title', () => {
      render(
        <E2NodeToolsModal
          e2node={mockE2Node}
          isOpen={true}
          onClose={mockOnClose}
          user={mockEditor}
        />
      )

      fireEvent.click(screen.getByText('Title Change'))

      expect(screen.getByText('Current title:')).toBeInTheDocument()
      expect(screen.getByDisplayValue('Test Node')).toBeInTheDocument()
    })

    it('shows warning about renaming', () => {
      render(
        <E2NodeToolsModal
          e2node={mockE2Node}
          isOpen={true}
          onClose={mockOnClose}
          user={mockEditor}
        />
      )

      fireEvent.click(screen.getByText('Title Change'))

      expect(screen.getByText(/Changing the node title will rename all writeups/)).toBeInTheDocument()
    })

    it('validates same title', async () => {
      render(
        <E2NodeToolsModal
          e2node={mockE2Node}
          isOpen={true}
          onClose={mockOnClose}
          user={mockEditor}
        />
      )

      fireEvent.click(screen.getByText('Title Change'))
      fireEvent.click(screen.getByRole('button', { name: 'Rename' }))

      await waitFor(() => {
        expect(screen.getByText('New title is the same as current title')).toBeInTheDocument()
      })
    })
  })

  describe('Order & Repair panel', () => {
    it('shows message when no writeups', () => {
      render(
        <E2NodeToolsModal
          e2node={mockE2Node}
          isOpen={true}
          onClose={mockOnClose}
          user={mockEditor}
        />
      )

      fireEvent.click(screen.getByText('Order & Repair'))

      // Check for partial message since it spans multiple elements
      expect(screen.getByText(/has no writeups/)).toBeInTheDocument()
      expect(screen.getByRole('button', { name: 'Repair Node' })).toBeInTheDocument()
    })

    it('shows writeups when available', () => {
      const e2nodeWithWriteups = {
        ...mockE2Node,
        group: [
          { node_id: 1, author: { title: 'Author1' }, writeuptype: { title: 'thing' }, reputation: 5 },
          { node_id: 2, author: { title: 'Author2' }, writeuptype: { title: 'idea' }, reputation: 10 }
        ]
      }

      render(
        <E2NodeToolsModal
          e2node={e2nodeWithWriteups}
          isOpen={true}
          onClose={mockOnClose}
          user={mockEditor}
        />
      )

      fireEvent.click(screen.getByText('Order & Repair'))

      expect(screen.getByText('Author1')).toBeInTheDocument()
      expect(screen.getByText('Author2')).toBeInTheDocument()
    })
  })

  describe('close behavior', () => {
    it('calls onClose when close button clicked', () => {
      render(
        <E2NodeToolsModal
          e2node={mockE2Node}
          isOpen={true}
          onClose={mockOnClose}
          user={mockEditor}
        />
      )

      fireEvent.click(screen.getByLabelText('Close'))

      expect(mockOnClose).toHaveBeenCalled()
    })
  })

  describe('editor flag handling', () => {
    it('works with editor property', () => {
      const userWithEditor = { ...mockNonEditor, editor: true }

      render(
        <E2NodeToolsModal
          e2node={mockE2Node}
          isOpen={true}
          onClose={mockOnClose}
          user={userWithEditor}
        />
      )

      expect(screen.getByTestId('modal')).toBeInTheDocument()
    })

    it('works with is_editor property', () => {
      const userWithIsEditor = { ...mockNonEditor, is_editor: true }

      render(
        <E2NodeToolsModal
          e2node={mockE2Node}
          isOpen={true}
          onClose={mockOnClose}
          user={userWithIsEditor}
        />
      )

      expect(screen.getByTestId('modal')).toBeInTheDocument()
    })
  })
})
