import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import NodeNotes from './NodeNotes'

// Mock child components
jest.mock('../LinkNode', () => {
  return function MockLinkNode({ type, title }) {
    return <a data-testid="linknode" data-type={type} data-title={title}>{title}</a>
  }
})

jest.mock('../ParseLinks', () => {
  return function MockParseLinks({ children }) {
    return <span data-testid="parselinks">{children}</span>
  }
})

global.fetch = jest.fn()

describe('NodeNotes Component', () => {
  beforeEach(() => {
    fetch.mockClear()
  })

  describe('rendering', () => {
    it('renders with no notes', () => {
      render(<NodeNotes nodeId={123} initialNotes={[]} currentUserId={456} />)
      expect(screen.getByText(/Node Notes/)).toBeInTheDocument()
      expect(screen.getByText(/(0)/)).toBeInTheDocument()
    })

    it('renders with notes count', () => {
      const notes = [
        { nodenote_id: 1, notenote_nodeid: 123, notetext: 'Test note', noter_user: 456, timestamp: '2025-01-01 12:00:00' }
      ]
      render(<NodeNotes nodeId={123} initialNotes={notes} currentUserId={456} />)
      expect(screen.getByText('Node Notes')).toBeInTheDocument()
      expect(screen.getByText('(1)')).toBeInTheDocument()
    })

    it('renders modern format note with username', () => {
      const notes = [
        {
          nodenote_id: 1,
          nodenote_nodeid: 123,
          notetext: 'This is a modern note',
          noter_user: 456,
          noter_username: 'testuser',
          timestamp: '2025-01-01 12:00:00'
        }
      ]
      render(<NodeNotes nodeId={123} initialNotes={notes} currentUserId={456} />)

      // Should show the username link
      const usernameLink = screen.getByTestId('linknode')
      expect(usernameLink).toHaveAttribute('data-title', 'testuser')
      expect(usernameLink).toHaveAttribute('data-type', 'user')

      // Should show the notetext
      expect(screen.getByText('This is a modern note')).toBeInTheDocument()
    })

    it('renders legacy format note without username', () => {
      const notes = [
        {
          nodenote_id: 1,
          nodenote_nodeid: 123,
          notetext: '[root[user]]: This is an old-style note',
          noter_user: 1,
          legacy_format: 1,
          timestamp: '2020-01-01 12:00:00'
        }
      ]
      render(<NodeNotes nodeId={123} initialNotes={notes} currentUserId={456} />)

      // Should NOT show a username link for legacy format
      expect(screen.queryByTestId('linknode')).not.toBeInTheDocument()

      // Should show the full notetext (author is embedded)
      expect(screen.getByText('[root[user]]: This is an old-style note')).toBeInTheDocument()
    })

    it('renders mix of modern and legacy notes correctly', () => {
      const notes = [
        {
          nodenote_id: 1,
          nodenote_nodeid: 123,
          notetext: '[olduser[user]]: Legacy note',
          noter_user: 1,
          legacy_format: 1,
          timestamp: '2020-01-01 12:00:00'
        },
        {
          nodenote_id: 2,
          nodenote_nodeid: 123,
          notetext: 'Modern note',
          noter_user: 456,
          noter_username: 'modernuser',
          timestamp: '2025-01-01 12:00:00'
        }
      ]
      render(<NodeNotes nodeId={123} initialNotes={notes} currentUserId={456} />)

      // Should have exactly one username link (for the modern note)
      const usernameLinks = screen.getAllByTestId('linknode')
      expect(usernameLinks).toHaveLength(1)
      expect(usernameLinks[0]).toHaveAttribute('data-title', 'modernuser')

      // Both notes should be visible
      expect(screen.getByText('[olduser[user]]: Legacy note')).toBeInTheDocument()
      expect(screen.getByText('Modern note')).toBeInTheDocument()
    })

    it('renders checkbox for notes with noter_user', () => {
      const notes = [
        {
          nodenote_id: 1,
          nodenote_nodeid: 123,
          notetext: 'Note with user',
          noter_user: 456,
          noter_username: 'testuser',
          timestamp: '2025-01-01 12:00:00'
        }
      ]
      render(<NodeNotes nodeId={123} initialNotes={notes} currentUserId={456} />)

      const checkbox = screen.getByRole('checkbox')
      expect(checkbox).toBeInTheDocument()
    })

    it('renders bullet for system notes (no noter_user)', () => {
      const notes = [
        {
          nodenote_id: 1,
          nodenote_nodeid: 123,
          notetext: 'System note',
          noter_user: 0,
          timestamp: '2025-01-01 12:00:00'
        }
      ]
      render(<NodeNotes nodeId={123} initialNotes={notes} currentUserId={456} />)

      expect(screen.queryByRole('checkbox')).not.toBeInTheDocument()
      expect(screen.getByText(/•/)).toBeInTheDocument()
    })
  })

  describe('add note functionality', () => {
    it('adds a note successfully', async () => {
      fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          notes: [
            {
              nodenote_id: 2,
              nodenote_nodeid: 123,
              notetext: 'New note',
              noter_user: 456,
              noter_username: 'testuser',
              timestamp: '2025-01-01 12:00:00'
            }
          ]
        })
      })

      render(<NodeNotes nodeId={123} initialNotes={[]} currentUserId={456} />)

      const input = screen.getByPlaceholderText('Add note...')
      const addButton = screen.getByText('Add Note')

      fireEvent.change(input, { target: { value: 'New note' } })
      fireEvent.click(addButton)

      await waitFor(() => {
        expect(fetch).toHaveBeenCalledWith(
          '/api/nodenotes/123/create',
          expect.objectContaining({
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            credentials: 'include',
            body: JSON.stringify({ notetext: 'New note' })
          })
        )
      })

      await waitFor(() => {
        expect(screen.getByText('New note')).toBeInTheDocument()
      })
    })
  })

  describe('delete note functionality', () => {
    it('deletes selected notes and uses API response', async () => {
      const initialNotes = [
        {
          nodenote_id: 1,
          nodenote_nodeid: 123,
          notetext: 'Note to delete',
          noter_user: 456,
          noter_username: 'testuser',
          timestamp: '2025-01-01 12:00:00'
        }
      ]

      // Mock DELETE response (no more notes after deletion)
      fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          notes: []
        })
      })

      render(<NodeNotes nodeId={123} initialNotes={initialNotes} currentUserId={456} />)

      // Select the note
      const checkbox = screen.getByRole('checkbox')
      fireEvent.click(checkbox)

      // Click delete button
      const deleteButton = screen.getByText(/Delete \(1\)/)
      fireEvent.click(deleteButton)

      await waitFor(() => {
        expect(fetch).toHaveBeenCalledWith(
          '/api/nodenotes/123/1/delete',
          expect.objectContaining({
            method: 'DELETE',
            credentials: 'include'
          })
        )
      })

      // Verify only one API call was made (DELETE, no extra GET)
      expect(fetch).toHaveBeenCalledTimes(1)

      // Note should be removed from display
      await waitFor(() => {
        expect(screen.queryByText('Note to delete')).not.toBeInTheDocument()
      })
    })
  })
})
