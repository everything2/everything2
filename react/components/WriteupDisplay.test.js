import React from 'react'
import { render, screen, fireEvent } from '@testing-library/react'
import WriteupDisplay from './WriteupDisplay'

// Mock the E2HtmlSanitizer
jest.mock('./Editor/E2HtmlSanitizer', () => ({
  renderE2Content: (text) => ({ html: text })
}))

// Mock LinkNode
jest.mock('./LinkNode', () => {
  return function MockLinkNode({ title, type }) {
    return <a data-testid="linknode" data-title={title} data-type={type || 'default'}>{title}</a>
  }
})

describe('WriteupDisplay Component', () => {
  const mockWriteup = {
    node_id: 123,
    title: 'Test Writeup',
    author: { node_id: 456, title: 'testuser' },
    parent: { title: 'Test Node' },
    doctext: 'This is a test writeup with [some links].',
    reputation: 5,
    upvotes: 7,
    downvotes: 2,
    writeuptype: 'thing',
    createtime: 1700000000,
    cools: []
  }

  const mockUser = {
    node_id: 789,
    is_guest: false,
    is_editor: false
  }

  const guestUser = {
    node_id: 0,
    is_guest: true,
    is_editor: false
  }

  describe('rendering', () => {
    it('renders writeup with all metadata', () => {
      render(<WriteupDisplay writeup={mockWriteup} user={mockUser} />)

      // New layout: (type) by author date - no parent title in header
      expect(screen.getByText('testuser')).toBeInTheDocument()
      expect(screen.getByText('thing')).toBeInTheDocument() // type without parens in link
      expect(screen.getByText(/Rep: \+5/)).toBeInTheDocument()
    })

    it('renders doctext content', () => {
      render(<WriteupDisplay writeup={mockWriteup} user={mockUser} />)

      const content = screen.getByText(/This is a test writeup/)
      expect(content).toBeInTheDocument()
    })

    it('displays reputation when available', () => {
      render(<WriteupDisplay writeup={mockWriteup} user={mockUser} />)

      // Legacy style shows just Rep: +N, not vote breakdown
      expect(screen.getByText(/Rep: \+5/)).toBeInTheDocument()
    })

    it('displays C!s when present', () => {
      const writeupWithCools = {
        ...mockWriteup,
        cools: [
          { node_id: 111, title: 'cooler1' },
          { node_id: 222, title: 'cooler2' }
        ]
      }

      render(<WriteupDisplay writeup={writeupWithCools} user={mockUser} />)

      // Legacy style: "2 C!s cooler1, cooler2"
      expect(screen.getByText(/C!/)).toBeInTheDocument()
      expect(screen.getByText('cooler1')).toBeInTheDocument()
      expect(screen.getByText('cooler2')).toBeInTheDocument()
    })

    it('handles missing optional fields', () => {
      const minimalWriteup = {
        node_id: 123,
        author: { title: 'testuser' },
        doctext: 'Minimal writeup'
      }

      render(<WriteupDisplay writeup={minimalWriteup} user={mockUser} />)

      expect(screen.getByText('Minimal writeup')).toBeInTheDocument()
    })

    it('renders content in content div', () => {
      render(<WriteupDisplay writeup={mockWriteup} user={mockUser} />)

      const content = screen.getByText(/This is a test writeup/)
      expect(content).toBeInTheDocument()
    })
  })

  describe('voting controls', () => {
    it('shows voting controls for logged-in non-authors', () => {
      render(<WriteupDisplay writeup={mockWriteup} user={mockUser} />)

      // Radio button voting controls with + and - labels
      expect(screen.getByLabelText('+')).toBeInTheDocument()
      expect(screen.getByLabelText('-')).toBeInTheDocument()
    })

    it('hides voting controls for guests', () => {
      render(<WriteupDisplay writeup={mockWriteup} user={guestUser} />)

      expect(screen.queryByLabelText('+')).not.toBeInTheDocument()
      expect(screen.queryByLabelText('-')).not.toBeInTheDocument()
    })

    it('hides voting controls for authors', () => {
      const authorUser = {
        node_id: 456, // Same as author in mockWriteup
        is_guest: false,
        is_editor: false
      }

      render(<WriteupDisplay writeup={mockWriteup} user={authorUser} />)

      expect(screen.queryByLabelText('+')).not.toBeInTheDocument()
      expect(screen.queryByLabelText('-')).not.toBeInTheDocument()
    })

    it('disables vote radios if user has already voted', () => {
      const votedWriteup = { ...mockWriteup, vote: 1 }

      render(<WriteupDisplay writeup={votedWriteup} user={mockUser} />)

      const upvoteRadio = screen.getByLabelText('+')
      const downvoteRadio = screen.getByLabelText('-')

      expect(upvoteRadio).toBeDisabled()
      expect(downvoteRadio).toBeDisabled()
    })

    it('marks active vote radio as checked', () => {
      const votedWriteup = { ...mockWriteup, vote: 1 }

      render(<WriteupDisplay writeup={votedWriteup} user={mockUser} />)

      const upvoteRadio = screen.getByLabelText('+')
      expect(upvoteRadio).toBeChecked()
    })

    it('can hide voting controls via prop', () => {
      render(<WriteupDisplay writeup={mockWriteup} user={mockUser} showVoting={false} />)

      expect(screen.queryByLabelText('+')).not.toBeInTheDocument()
    })
  })

  describe('edge cases', () => {
    it('returns null for missing writeup', () => {
      const { container } = render(<WriteupDisplay writeup={null} user={mockUser} />)

      expect(container).toBeEmptyDOMElement()
    })

    it('handles negative reputation', () => {
      const negRepWriteup = { ...mockWriteup, reputation: -3 }

      render(<WriteupDisplay writeup={negRepWriteup} user={mockUser} />)

      expect(screen.getByText('Rep: -3')).toBeInTheDocument()
    })

    it('handles zero reputation', () => {
      const zeroRepWriteup = { ...mockWriteup, reputation: 0 }

      render(<WriteupDisplay writeup={zeroRepWriteup} user={mockUser} />)

      expect(screen.getByText('Rep: 0')).toBeInTheDocument()
    })
  })
})
