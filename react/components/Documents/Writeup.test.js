import React from 'react'
import { render, screen, fireEvent } from '@testing-library/react'
import Writeup from './Writeup'

// Mock WriteupDisplay
jest.mock('../WriteupDisplay', () => {
  return function MockWriteupDisplay({ writeup, isDraft }) {
    return <div data-testid="writeup-display">{writeup.title} {isDraft && '(draft)'}</div>
  }
})

// Mock LinkNode
jest.mock('../LinkNode', () => {
  return function MockLinkNode({ title }) {
    return <a data-testid="linknode">{title}</a>
  }
})

// Mock InlineWriteupEditor
jest.mock('../InlineWriteupEditor', () => {
  return function MockInlineWriteupEditor({ e2nodeTitle }) {
    return <div data-testid="inline-editor">Add a Writeup to "{e2nodeTitle}"</div>
  }
})

// Mock E2NodeToolsModal
jest.mock('../E2NodeToolsModal', () => {
  return function MockE2NodeToolsModal() {
    return null
  }
})

describe('Writeup Component', () => {
  const mockWriteup = {
    node_id: 100,
    title: 'Test Writeup (thing)',
    doctext: '<p>Test content</p>',
    author: { node_id: 200, title: 'testauthor' },
    writeuptype: 'thing',
    createtime: '2025-01-01 12:00:00'
  }

  const mockParentE2node = {
    node_id: 50,
    title: 'Test E2Node',
    group: [
      {
        node_id: 100,
        title: 'Test Writeup (thing)',
        author: { node_id: 200, title: 'testauthor' }
      }
    ],
    softlinks: [
      { node_id: 10, title: 'Related Node', type: 'e2node' }
    ],
    locked: false
  }

  const mockUser = {
    node_id: 300,
    title: 'currentuser',
    guest: false,
    is_guest: false
  }

  const mockGuestUser = {
    node_id: 0,
    title: 'Guest User',
    guest: true,
    is_guest: true
  }

  describe('rendering', () => {
    it('renders the writeup display', () => {
      render(
        <Writeup
          data={{
            writeup: mockWriteup,
            user: mockUser,
            parent_e2node: mockParentE2node
          }}
        />
      )

      expect(screen.getByTestId('writeup-display')).toBeInTheDocument()
    })

    it('shows loading state when no data', () => {
      render(<Writeup data={null} />)

      expect(screen.getByText('Loading...')).toBeInTheDocument()
    })

    it('shows error when writeup is missing', () => {
      render(
        <Writeup
          data={{
            writeup: null,
            user: mockUser,
            parent_e2node: mockParentE2node
          }}
        />
      )

      expect(screen.getByText('Writeup not found')).toBeInTheDocument()
    })

    it('renders softlinks from parent e2node', () => {
      render(
        <Writeup
          data={{
            writeup: mockWriteup,
            user: mockUser,
            parent_e2node: mockParentE2node
          }}
        />
      )

      expect(screen.getByText('Related Node')).toBeInTheDocument()
    })
  })

  describe('Add a Writeup inline editor visibility', () => {
    it('shows inline editor for logged-in user without existing writeup on unlocked node', () => {
      // Current user (node_id: 300) does not have a writeup on this e2node
      // The parent_e2node.group only has writeup by author 200
      render(
        <Writeup
          data={{
            writeup: mockWriteup,
            user: mockUser,
            parent_e2node: mockParentE2node
          }}
        />
      )

      expect(screen.getByTestId('inline-editor')).toBeInTheDocument()
      expect(screen.getByText(/Add a Writeup to "Test E2Node"/)).toBeInTheDocument()
    })

    it('hides inline editor for guest users', () => {
      render(
        <Writeup
          data={{
            writeup: mockWriteup,
            user: mockGuestUser,
            parent_e2node: mockParentE2node
          }}
        />
      )

      expect(screen.queryByTestId('inline-editor')).not.toBeInTheDocument()
    })

    it('hides inline editor when user already has a writeup on the parent e2node', () => {
      // User 300 already has a writeup in the group
      const parentWithUserWriteup = {
        ...mockParentE2node,
        group: [
          ...mockParentE2node.group,
          {
            node_id: 101,
            title: 'Another Writeup (idea)',
            author: { node_id: 300, title: 'currentuser' }
          }
        ]
      }

      render(
        <Writeup
          data={{
            writeup: mockWriteup,
            user: mockUser,
            parent_e2node: parentWithUserWriteup
          }}
        />
      )

      expect(screen.queryByTestId('inline-editor')).not.toBeInTheDocument()
    })

    it('hides inline editor when user is the author of current writeup (already has one)', () => {
      // The writeup author is the same as the current user
      const userAsAuthor = { ...mockUser, node_id: 200 }

      render(
        <Writeup
          data={{
            writeup: mockWriteup,
            user: userAsAuthor,
            parent_e2node: mockParentE2node
          }}
        />
      )

      expect(screen.queryByTestId('inline-editor')).not.toBeInTheDocument()
    })

    it('hides inline editor when parent e2node is locked', () => {
      const lockedParent = {
        ...mockParentE2node,
        locked: true,
        lock_reason: 'Editorial decision',
        lock_user_title: 'SomeEditor'
      }

      render(
        <Writeup
          data={{
            writeup: mockWriteup,
            user: mockUser,
            parent_e2node: lockedParent
          }}
        />
      )

      expect(screen.queryByTestId('inline-editor')).not.toBeInTheDocument()
    })

    it('hides inline editor when no parent_e2node data is available', () => {
      render(
        <Writeup
          data={{
            writeup: mockWriteup,
            user: mockUser,
            parent_e2node: null
          }}
        />
      )

      expect(screen.queryByTestId('inline-editor')).not.toBeInTheDocument()
    })

    it('handles string vs number node_id comparison correctly', () => {
      // User node_id as string, author node_id as number (type mismatch)
      const userWithStringId = { ...mockUser, node_id: '300' }
      const parentWithNumberAuthor = {
        ...mockParentE2node,
        group: [
          {
            node_id: 101,
            title: 'User Writeup',
            author: { node_id: 300, title: 'currentuser' } // number
          }
        ]
      }

      render(
        <Writeup
          data={{
            writeup: mockWriteup,
            user: userWithStringId,
            parent_e2node: parentWithNumberAuthor
          }}
        />
      )

      // Should NOT show editor because user (string '300') matches author (number 300)
      expect(screen.queryByTestId('inline-editor')).not.toBeInTheDocument()
    })
  })

  describe('locked node warning', () => {
    it('displays warning box when parent node is locked with user and reason', () => {
      const lockedParent = {
        ...mockParentE2node,
        locked: true,
        lock_reason: 'Editorial decision',
        lock_user_title: 'SomeEditor'
      }

      render(
        <Writeup
          data={{
            writeup: mockWriteup,
            user: mockUser,
            parent_e2node: lockedParent
          }}
        />
      )

      expect(screen.getByText(/This node is locked/)).toBeInTheDocument()
      expect(screen.getByText(/SomeEditor/)).toBeInTheDocument()
      expect(screen.getByText(/Editorial decision/)).toBeInTheDocument()
      expect(screen.getByText(/not accepting new contributions/)).toBeInTheDocument()
    })

    it('displays warning box when locked without lock_user_title', () => {
      const lockedParent = {
        ...mockParentE2node,
        locked: true,
        lock_reason: 'Content freeze',
        lock_user_title: null
      }

      render(
        <Writeup
          data={{
            writeup: mockWriteup,
            user: mockUser,
            parent_e2node: lockedParent
          }}
        />
      )

      expect(screen.getByText(/This node is locked/)).toBeInTheDocument()
      expect(screen.getByText(/Content freeze/)).toBeInTheDocument()
    })

    it('does not display warning for guests even when locked', () => {
      const lockedParent = {
        ...mockParentE2node,
        locked: true,
        lock_reason: 'Editorial decision'
      }

      render(
        <Writeup
          data={{
            writeup: mockWriteup,
            user: mockGuestUser,
            parent_e2node: lockedParent
          }}
        />
      )

      // Guests should not see the locked warning (they can't add writeups anyway)
      expect(screen.queryByText(/This node is locked/)).not.toBeInTheDocument()
    })

    it('does not display warning when node is not locked', () => {
      render(
        <Writeup
          data={{
            writeup: mockWriteup,
            user: mockUser,
            parent_e2node: mockParentE2node
          }}
        />
      )

      expect(screen.queryByText(/This node is locked/)).not.toBeInTheDocument()
    })
  })

  describe('editing functionality', () => {
    it('shows edit button for writeup owner', () => {
      const userAsAuthor = { ...mockUser, node_id: 200 }

      render(
        <Writeup
          data={{
            writeup: mockWriteup,
            user: userAsAuthor,
            parent_e2node: mockParentE2node
          }}
        />
      )

      expect(screen.getByTitle(/Edit your writeup/)).toBeInTheDocument()
    })

    it('shows edit button for editors', () => {
      const editorUser = { ...mockUser, editor: true, is_editor: true }

      render(
        <Writeup
          data={{
            writeup: mockWriteup,
            user: editorUser,
            parent_e2node: mockParentE2node
          }}
        />
      )

      expect(screen.getByTitle(/Edit testauthor's writeup/)).toBeInTheDocument()
    })

    it('does not show edit button for non-owner non-editor', () => {
      render(
        <Writeup
          data={{
            writeup: mockWriteup,
            user: mockUser,
            parent_e2node: mockParentE2node
          }}
        />
      )

      expect(screen.queryByTitle(/Edit/)).not.toBeInTheDocument()
    })

    it('does not show edit button for guests', () => {
      render(
        <Writeup
          data={{
            writeup: mockWriteup,
            user: mockGuestUser,
            parent_e2node: mockParentE2node
          }}
        />
      )

      expect(screen.queryByTitle(/Edit/)).not.toBeInTheDocument()
    })
  })

  describe('E2 Node Tools button', () => {
    it('shows tools button for editors when parent_e2node exists', () => {
      const editorUser = { ...mockUser, editor: true, is_editor: true }

      render(
        <Writeup
          data={{
            writeup: mockWriteup,
            user: editorUser,
            parent_e2node: mockParentE2node
          }}
        />
      )

      expect(screen.getByTitle(/Editor node tools/)).toBeInTheDocument()
    })

    it('does not show tools button for non-editors', () => {
      render(
        <Writeup
          data={{
            writeup: mockWriteup,
            user: mockUser,
            parent_e2node: mockParentE2node
          }}
        />
      )

      expect(screen.queryByTitle(/Editor node tools/)).not.toBeInTheDocument()
    })

    it('does not show tools button when no parent_e2node', () => {
      const editorUser = { ...mockUser, editor: true, is_editor: true }

      render(
        <Writeup
          data={{
            writeup: mockWriteup,
            user: editorUser,
            parent_e2node: null
          }}
        />
      )

      expect(screen.queryByTitle(/Editor node tools/)).not.toBeInTheDocument()
    })
  })

  describe('edge cases', () => {
    it('handles empty parent_e2node.group', () => {
      const parentWithNoWriteups = {
        ...mockParentE2node,
        group: []
      }

      render(
        <Writeup
          data={{
            writeup: mockWriteup,
            user: mockUser,
            parent_e2node: parentWithNoWriteups
          }}
        />
      )

      // User should see the inline editor since there are no writeups
      expect(screen.getByTestId('inline-editor')).toBeInTheDocument()
    })

    it('handles undefined parent_e2node.group', () => {
      const parentWithUndefinedGroup = {
        ...mockParentE2node,
        group: undefined
      }

      render(
        <Writeup
          data={{
            writeup: mockWriteup,
            user: mockUser,
            parent_e2node: parentWithUndefinedGroup
          }}
        />
      )

      // Should handle gracefully and show editor
      expect(screen.getByTestId('inline-editor')).toBeInTheDocument()
    })

    it('handles writeup without author', () => {
      const writeupNoAuthor = {
        ...mockWriteup,
        author: null
      }

      render(
        <Writeup
          data={{
            writeup: writeupNoAuthor,
            user: mockUser,
            parent_e2node: mockParentE2node
          }}
        />
      )

      // Should render without crashing
      expect(screen.getByTestId('writeup-display')).toBeInTheDocument()
    })

    it('handles parent group writeup without author', () => {
      const parentWithBadWriteup = {
        ...mockParentE2node,
        group: [
          {
            node_id: 101,
            title: 'Orphan Writeup',
            author: null
          }
        ]
      }

      render(
        <Writeup
          data={{
            writeup: mockWriteup,
            user: mockUser,
            parent_e2node: parentWithBadWriteup
          }}
        />
      )

      // Should handle gracefully and show editor (no valid author to match)
      expect(screen.getByTestId('inline-editor')).toBeInTheDocument()
    })
  })
})
