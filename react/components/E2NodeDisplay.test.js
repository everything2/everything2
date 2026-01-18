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

// Mock InlineWriteupEditor
jest.mock('./InlineWriteupEditor', () => {
  return function MockInlineWriteupEditor() {
    return <div data-testid="inline-editor">Add a Writeup</div>
  }
})

// Mock E2NodeToolsModal
jest.mock('./E2NodeToolsModal', () => {
  return function MockE2NodeToolsModal() {
    return null
  }
})

// Mock GoogleAds
jest.mock('./Layout/GoogleAds', () => ({
  InContentAd: ({ show }) => show ? <div data-testid="in-content-ad">Ad</div> : null
}))

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
    it('does not render e2node title (handled by zen.mc pageheader)', () => {
      render(<E2NodeDisplay e2node={mockE2Node} user={mockUser} />)

      // Title is not rendered by E2NodeDisplay, it's in zen.mc #pageheader
      expect(screen.queryByText('Test E2Node')).not.toBeInTheDocument()
    })

    it('does not render createdby info (handled by zen.mc pageheader)', () => {
      render(<E2NodeDisplay e2node={mockE2Node} user={mockUser} />)

      // Createdby info is not rendered by E2NodeDisplay, it's in zen.mc #pageheader
      expect(screen.queryByText(/Created by/)).not.toBeInTheDocument()
      expect(screen.queryByText('creator')).not.toBeInTheDocument()
    })

    it('renders all writeups', () => {
      render(<E2NodeDisplay e2node={mockE2Node} user={mockUser} />)

      const writeups = screen.getAllByTestId('writeup')
      expect(writeups).toHaveLength(2)
      expect(screen.getByText('Writeup 1')).toBeInTheDocument()
      expect(screen.getByText('Writeup 2')).toBeInTheDocument()
    })

    it('renders softlinks', () => {
      render(<E2NodeDisplay e2node={mockE2Node} user={mockUser} />)

      // Softlinks are rendered in a table, no "Softlinks:" label
      expect(screen.getByText('Related Node 1')).toBeInTheDocument()
      expect(screen.getByText('Related Node 2')).toBeInTheDocument()
    })

    it('shows message when no writeups', () => {
      const emptyE2Node = {
        ...mockE2Node,
        group: []
      }

      render(<E2NodeDisplay e2node={emptyE2Node} user={mockUser} />)

      expect(screen.getByText('There are no writeups for this node yet.')).toBeInTheDocument()
    })

    it('hides softlinks section when empty', () => {
      const noSoftlinksE2Node = {
        ...mockE2Node,
        softlinks: []
      }

      render(<E2NodeDisplay e2node={noSoftlinksE2Node} user={mockUser} />)

      // No softlinks should be rendered
      expect(screen.queryByText('Related Node 1')).not.toBeInTheDocument()
    })

    it('handles missing createdby', () => {
      const noCreatorE2Node = {
        ...mockE2Node,
        createdby: null
      }

      render(<E2NodeDisplay e2node={noCreatorE2Node} user={mockUser} />)

      // Component doesn't render createdby, so this just ensures no crash
      const writeups = screen.getAllByTestId('writeup')
      expect(writeups).toHaveLength(2)
    })

    it('renders container with proper class', () => {
      const { container } = render(<E2NodeDisplay e2node={mockE2Node} user={mockUser} />)

      expect(container.querySelector('.e2node-display')).toBeInTheDocument()
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

      // No softlinks should be rendered
      expect(screen.queryByText('Related Node 1')).not.toBeInTheDocument()
    })

    it('handles undefined group', () => {
      const noGroupE2Node = {
        ...mockE2Node,
        group: undefined
      }

      render(<E2NodeDisplay e2node={noGroupE2Node} user={mockUser} />)

      expect(screen.getByText('There are no writeups for this node yet.')).toBeInTheDocument()
    })
  })

  describe('inline editor visibility', () => {
    it('shows inline editor for logged-in user without existing writeup on unlocked node', () => {
      const unlockedE2Node = {
        ...mockE2Node,
        locked: false,
        group: []
      }
      const loggedInUser = { node_id: 999, guest: false }

      render(<E2NodeDisplay e2node={unlockedE2Node} user={loggedInUser} />)

      expect(screen.getByTestId('inline-editor')).toBeInTheDocument()
    })

    it('hides inline editor when node is locked', () => {
      const lockedE2Node = {
        ...mockE2Node,
        locked: true,
        lock_reason: 'Editorial decision',
        lock_user_id: 123,
        group: []
      }
      const loggedInUser = { node_id: 999, guest: false }

      render(<E2NodeDisplay e2node={lockedE2Node} user={loggedInUser} />)

      expect(screen.queryByTestId('inline-editor')).not.toBeInTheDocument()
    })

    it('hides inline editor for guest users even on unlocked nodes', () => {
      const unlockedE2Node = {
        ...mockE2Node,
        locked: false,
        group: []
      }
      const guestUser = { node_id: 0, guest: true }

      render(<E2NodeDisplay e2node={unlockedE2Node} user={guestUser} />)

      expect(screen.queryByTestId('inline-editor')).not.toBeInTheDocument()
    })

    it('hides inline editor when user already has a writeup on the node', () => {
      const userId = 999
      const e2NodeWithUserWriteup = {
        ...mockE2Node,
        locked: false,
        group: [
          {
            node_id: 1,
            title: 'User Writeup',
            author: { node_id: userId, title: 'testuser' },
            doctext: 'Content'
          }
        ]
      }
      const loggedInUser = { node_id: userId, guest: false }

      render(<E2NodeDisplay e2node={e2NodeWithUserWriteup} user={loggedInUser} />)

      expect(screen.queryByTestId('inline-editor')).not.toBeInTheDocument()
    })
  })

  describe('locked node warning', () => {
    it('displays warning box when node is locked with user and reason', () => {
      const lockedE2Node = {
        ...mockE2Node,
        locked: true,
        lock_reason: 'Editorial decision',
        lock_user_title: 'SomeEditor',
        group: []
      }

      render(<E2NodeDisplay e2node={lockedE2Node} user={mockUser} />)

      expect(screen.getByText(/This node is locked/)).toBeInTheDocument()
      expect(screen.getByText(/SomeEditor/)).toBeInTheDocument()
      expect(screen.getByText(/Editorial decision/)).toBeInTheDocument()
      expect(screen.getByText(/not accepting new contributions/)).toBeInTheDocument()
    })

    it('displays warning box when node is locked without user title', () => {
      const lockedE2Node = {
        ...mockE2Node,
        locked: true,
        lock_reason: 'Content freeze',
        lock_user_title: null,
        group: []
      }

      render(<E2NodeDisplay e2node={lockedE2Node} user={mockUser} />)

      expect(screen.getByText(/This node is locked/)).toBeInTheDocument()
      expect(screen.getByText(/Content freeze/)).toBeInTheDocument()
      expect(screen.queryByText(/by/)).not.toBeInTheDocument()
    })

    it('displays warning box when node is locked without reason', () => {
      const lockedE2Node = {
        ...mockE2Node,
        locked: true,
        lock_reason: null,
        lock_user_title: 'SomeEditor',
        group: []
      }

      render(<E2NodeDisplay e2node={lockedE2Node} user={mockUser} />)

      expect(screen.getByText(/This node is locked/)).toBeInTheDocument()
      expect(screen.getByText(/SomeEditor/)).toBeInTheDocument()
    })

    it('does not display warning when node is not locked', () => {
      const unlockedE2Node = {
        ...mockE2Node,
        locked: false,
        group: []
      }

      render(<E2NodeDisplay e2node={unlockedE2Node} user={mockUser} />)

      expect(screen.queryByText(/This node is locked/)).not.toBeInTheDocument()
    })
  })

  describe('guest nodeshell experience', () => {
    const guestUser = { node_id: 0, guest: true }
    const nodeshellE2Node = {
      ...mockE2Node,
      group: []
    }

    it('shows guest nodeshell message for guest users on empty nodes', () => {
      render(<E2NodeDisplay e2node={nodeshellE2Node} user={guestUser} />)
      expect(screen.getByText(/user-created topic that doesn't have any content yet/)).toBeInTheDocument()
    })

    it('shows sign in CTA for guest users', () => {
      render(<E2NodeDisplay e2node={nodeshellE2Node} user={guestUser} />)
      expect(screen.getByRole('link', { name: 'Sign In' })).toBeInTheDocument()
      expect(screen.getByRole('link', { name: 'Register here' })).toBeInTheDocument()
    })

    it('shows best entries when provided', () => {
      const bestEntries = [
        { writeup_id: 1, node_id: 100, title: 'Best Entry 1', author: { title: 'Author1' } },
        { writeup_id: 2, node_id: 101, title: 'Best Entry 2', author: { title: 'Author2' } }
      ]
      render(<E2NodeDisplay e2node={nodeshellE2Node} user={guestUser} bestEntries={bestEntries} />)
      expect(screen.getByText('Best Entry 1')).toBeInTheDocument()
      expect(screen.getByText('Best Entry 2')).toBeInTheDocument()
    })

    it('shows ads every 4 items in best entries', () => {
      const bestEntries = Array.from({ length: 10 }, (_, i) => ({
        writeup_id: i + 1,
        node_id: i + 100,
        title: `Best Entry ${i + 1}`,
        author: { title: `Author${i + 1}` }
      }))
      render(<E2NodeDisplay e2node={nodeshellE2Node} user={guestUser} bestEntries={bestEntries} />)
      // Ads should appear after items 4 and 8
      const ads = screen.getAllByTestId('in-content-ad')
      expect(ads).toHaveLength(2)
    })

    it('does not show ad after last best entry item', () => {
      const bestEntries = Array.from({ length: 4 }, (_, i) => ({
        writeup_id: i + 1,
        node_id: i + 100,
        title: `Best Entry ${i + 1}`,
        author: { title: `Author${i + 1}` }
      }))
      render(<E2NodeDisplay e2node={nodeshellE2Node} user={guestUser} bestEntries={bestEntries} />)
      // With exactly 4 items, no ad should show
      expect(screen.queryByTestId('in-content-ad')).not.toBeInTheDocument()
    })

    it('does not show guest nodeshell message for logged-in users', () => {
      const loggedInUser = { node_id: 999, guest: false }
      render(<E2NodeDisplay e2node={nodeshellE2Node} user={loggedInUser} />)
      expect(screen.queryByText(/user-created topic/)).not.toBeInTheDocument()
      expect(screen.getByText('There are no writeups for this node yet.')).toBeInTheDocument()
    })
  })
})
