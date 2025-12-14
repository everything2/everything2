import React from 'react'
import { render, screen } from '@testing-library/react'
import E2NodeDisplay from './E2NodeDisplay'

// Mock WriteupDisplay
jest.mock('./WriteupDisplay', () => {
  return function MockWriteupDisplay({ writeup }) {
    return <div data-testid="writeup">{writeup.title}</div>
  }
})

// Mock LinkNode
jest.mock('./LinkNode', () => {
  return function MockLinkNode({ title }) {
    return <a data-testid="linknode">{title}</a>
  }
})

describe('E2NodeDisplay Component', () => {
  const mockE2Node = {
    title: 'Test E2Node',
    createdby: { title: 'creator' },
    group: [
      {
        node_id: 1,
        title: 'Writeup 1',
        author: { title: 'author1' },
        doctext: 'Content 1'
      },
      {
        node_id: 2,
        title: 'Writeup 2',
        author: { title: 'author2' },
        doctext: 'Content 2'
      }
    ],
    softlinks: [
      { node_id: 10, title: 'Related Node 1', type: 'e2node', hits: 5 },
      { node_id: 11, title: 'Related Node 2', type: 'e2node', hits: 3 }
    ]
  }

  const mockUser = {
    node_id: 123,
    is_guest: false
  }

  describe('rendering', () => {
    it('renders e2node title', () => {
      render(<E2NodeDisplay e2node={mockE2Node} user={mockUser} />)

      expect(screen.getByText('Test E2Node')).toBeInTheDocument()
    })

    it('renders createdby info', () => {
      render(<E2NodeDisplay e2node={mockE2Node} user={mockUser} />)

      expect(screen.getByText(/Created by/)).toBeInTheDocument()
      expect(screen.getByText('creator')).toBeInTheDocument()
    })

    it('renders all writeups', () => {
      render(<E2NodeDisplay e2node={mockE2Node} user={mockUser} />)

      const writeups = screen.getAllByTestId('writeup')
      expect(writeups).toHaveLength(2)
      expect(screen.getByText('Writeup 1')).toBeInTheDocument()
      expect(screen.getByText('Writeup 2')).toBeInTheDocument()
    })

    it('renders softlinks with hit counts', () => {
      render(<E2NodeDisplay e2node={mockE2Node} user={mockUser} />)

      expect(screen.getByText(/Softlinks:/)).toBeInTheDocument()
      expect(screen.getByText('Related Node 1')).toBeInTheDocument()
      expect(screen.getByText('Related Node 2')).toBeInTheDocument()
      expect(screen.getByText('(5)')).toBeInTheDocument()
      expect(screen.getByText('(3)')).toBeInTheDocument()
    })

    it('shows message when no writeups', () => {
      const emptyE2Node = {
        ...mockE2Node,
        group: []
      }

      render(<E2NodeDisplay e2node={emptyE2Node} user={mockUser} />)

      expect(screen.getByText('No writeups yet.')).toBeInTheDocument()
    })

    it('hides softlinks section when empty', () => {
      const noSoftlinksE2Node = {
        ...mockE2Node,
        softlinks: []
      }

      render(<E2NodeDisplay e2node={noSoftlinksE2Node} user={mockUser} />)

      expect(screen.queryByText(/Softlinks:/)).not.toBeInTheDocument()
    })

    it('handles missing createdby', () => {
      const noCreatorE2Node = {
        ...mockE2Node,
        createdby: null
      }

      render(<E2NodeDisplay e2node={noCreatorE2Node} user={mockUser} />)

      expect(screen.queryByText(/Created by/)).not.toBeInTheDocument()
    })

    it('inherits font styles for title', () => {
      render(<E2NodeDisplay e2node={mockE2Node} user={mockUser} />)

      const title = screen.getByText('Test E2Node')
      expect(title).toHaveStyle({ fontSize: 'inherit' })
    })
  })

  describe('edge cases', () => {
    it('returns null for missing e2node', () => {
      const { container } = render(<E2NodeDisplay e2node={null} user={mockUser} />)

      expect(container).toBeEmptyDOMElement()
    })

    it('handles undefined softlinks', () => {
      const noSoftlinksE2Node = {
        ...mockE2Node,
        softlinks: undefined
      }

      render(<E2NodeDisplay e2node={noSoftlinksE2Node} user={mockUser} />)

      expect(screen.queryByText(/Softlinks:/)).not.toBeInTheDocument()
    })

    it('handles undefined group', () => {
      const noGroupE2Node = {
        ...mockE2Node,
        group: undefined
      }

      render(<E2NodeDisplay e2node={noGroupE2Node} user={mockUser} />)

      expect(screen.getByText('No writeups yet.')).toBeInTheDocument()
    })
  })
})
