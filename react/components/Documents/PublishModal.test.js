import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import '@testing-library/jest-dom'

// Import the component to test internal parseDraftTitle function
// We'll test it via the component's behavior

// Mock the hooks
jest.mock('../../hooks/usePublishDraft', () => ({
  useWriteuptypes: jest.fn(() => ({
    writeuptypes: [
      { node_id: 1, title: 'thing' },
      { node_id: 2, title: 'idea' },
      { node_id: 3, title: 'person' }
    ],
    selectedWriteuptypeId: 1,
    setSelectedWriteuptypeId: jest.fn()
  })),
  useSetParentE2node: jest.fn(() => ({
    setParentE2node: jest.fn(),
    loading: false,
    error: null
  })),
  usePublishDraft: jest.fn(() => ({
    publishDraft: jest.fn(),
    publishing: false,
    error: null,
    setError: jest.fn()
  }))
}))

// Mock fetch for autocomplete
global.fetch = jest.fn(() =>
  Promise.resolve({
    json: () => Promise.resolve({ success: true, findings: [] })
  })
)

import PublishModal from './PublishModal'
import { useWriteuptypes } from '../../hooks/usePublishDraft'

describe('PublishModal', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    // Reset useWriteuptypes mock to default state
    useWriteuptypes.mockReturnValue({
      writeuptypes: [
        { node_id: 1, title: 'thing' },
        { node_id: 2, title: 'idea' },
        { node_id: 3, title: 'person' }
      ],
      selectedWriteuptypeId: 1,
      setSelectedWriteuptypeId: jest.fn()
    })
  })

  describe('parseDraftTitle behavior', () => {
    it('pre-fills e2node title without writeuptype suffix for unpublished writeup', () => {
      // Draft title: "good poetry (thing)" - should extract "good poetry"
      render(
        <PublishModal
          draft={{ node_id: 123, title: 'good poetry (thing)' }}
          onSuccess={jest.fn()}
          onClose={jest.fn()}
        />
      )

      const input = screen.getByPlaceholderText(/enter the e2node title/i)
      expect(input.value).toBe('good poetry')
    })

    it('pre-fills full title when no writeuptype suffix present', () => {
      // New draft without writeuptype suffix
      render(
        <PublishModal
          draft={{ node_id: 123, title: 'my new draft' }}
          onSuccess={jest.fn()}
          onClose={jest.fn()}
        />
      )

      const input = screen.getByPlaceholderText(/enter the e2node title/i)
      expect(input.value).toBe('my new draft')
    })

    it('handles titles with parentheses that are not writeuptypes', () => {
      // Title with parentheses that are part of the content
      render(
        <PublishModal
          draft={{ node_id: 123, title: 'something (with parens) in middle' }}
          onSuccess={jest.fn()}
          onClose={jest.fn()}
        />
      )

      // Should extract everything before the last parenthetical
      const input = screen.getByPlaceholderText(/enter the e2node title/i)
      expect(input.value).toBe('something (with parens) in middle')
    })

    it('extracts writeuptype from title and triggers selection', async () => {
      const setSelectedWriteuptypeId = jest.fn()
      useWriteuptypes.mockReturnValue({
        writeuptypes: [
          { node_id: 1, title: 'thing' },
          { node_id: 2, title: 'idea' },
          { node_id: 3, title: 'person' }
        ],
        selectedWriteuptypeId: null, // Initially null
        setSelectedWriteuptypeId
      })

      render(
        <PublishModal
          draft={{ node_id: 123, title: 'test node (idea)' }}
          onSuccess={jest.fn()}
          onClose={jest.fn()}
        />
      )

      // Wait for the useEffect to fire
      await waitFor(() => {
        expect(setSelectedWriteuptypeId).toHaveBeenCalledWith(2) // idea's node_id
      })
    })

    it('overrides default "thing" selection when title contains different writeuptype', async () => {
      // This tests the race condition fix: useWriteuptypes defaults to 'thing',
      // but if the draft title contains a different writeuptype (like 'howto'),
      // the component should still set the correct type
      const setSelectedWriteuptypeId = jest.fn()
      useWriteuptypes.mockReturnValue({
        writeuptypes: [
          { node_id: 1, title: 'thing' },
          { node_id: 5, title: 'howto' },
          { node_id: 6, title: 'poetry' }
        ],
        selectedWriteuptypeId: 1, // Already defaulted to 'thing' (simulating race condition)
        setSelectedWriteuptypeId
      })

      render(
        <PublishModal
          draft={{ node_id: 456, title: 'quick brown fox (howto)' }}
          onSuccess={jest.fn()}
          onClose={jest.fn()}
        />
      )

      // Should override the 'thing' default with 'howto' from the title
      await waitFor(() => {
        expect(setSelectedWriteuptypeId).toHaveBeenCalledWith(5) // howto's node_id
      })
    })

    it('handles empty draft title', () => {
      render(
        <PublishModal
          draft={{ node_id: 123, title: '' }}
          onSuccess={jest.fn()}
          onClose={jest.fn()}
        />
      )

      const input = screen.getByPlaceholderText(/enter the e2node title/i)
      expect(input.value).toBe('')
    })

    it('handles undefined draft', () => {
      render(
        <PublishModal
          draft={undefined}
          onSuccess={jest.fn()}
          onClose={jest.fn()}
        />
      )

      const input = screen.getByPlaceholderText(/enter the e2node title/i)
      expect(input.value).toBe('')
    })
  })

  describe('modal behavior', () => {
    it('renders the modal with correct title', () => {
      render(
        <PublishModal
          draft={{ node_id: 123, title: 'Test Draft' }}
          onSuccess={jest.fn()}
          onClose={jest.fn()}
        />
      )

      expect(screen.getByText('Publish Draft')).toBeInTheDocument()
      expect(screen.getByText(/Publishing as:/)).toBeInTheDocument()
    })

    it('calls onClose when Close button is clicked', () => {
      const onClose = jest.fn()
      render(
        <PublishModal
          draft={{ node_id: 123, title: 'Test Draft' }}
          onSuccess={jest.fn()}
          onClose={onClose}
        />
      )

      fireEvent.click(screen.getByText('Close'))
      expect(onClose).toHaveBeenCalled()
    })

    it('calls onClose when Cancel button is clicked', () => {
      const onClose = jest.fn()
      render(
        <PublishModal
          draft={{ node_id: 123, title: 'Test Draft' }}
          onSuccess={jest.fn()}
          onClose={onClose}
        />
      )

      fireEvent.click(screen.getByText('Cancel'))
      expect(onClose).toHaveBeenCalled()
    })

    it('shows writeuptype dropdown with options', () => {
      render(
        <PublishModal
          draft={{ node_id: 123, title: 'Test Draft' }}
          onSuccess={jest.fn()}
          onClose={jest.fn()}
        />
      )

      expect(screen.getByText('thing')).toBeInTheDocument()
      expect(screen.getByText('idea')).toBeInTheDocument()
      expect(screen.getByText('person')).toBeInTheDocument()
    })

    it('shows dynamic title preview with e2node title and writeup type', () => {
      // Reset mock to ensure clean state
      useWriteuptypes.mockReturnValue({
        writeuptypes: [
          { node_id: 1, title: 'thing' },
          { node_id: 2, title: 'idea' },
          { node_id: 3, title: 'person' }
        ],
        selectedWriteuptypeId: 1,
        setSelectedWriteuptypeId: jest.fn()
      })

      render(
        <PublishModal
          draft={{ node_id: 123, title: 'Test Draft' }}
          onSuccess={jest.fn()}
          onClose={jest.fn()}
        />
      )

      // The title preview should show e2node title with selected writeup type
      // Default selectedWriteuptypeId is 1 (thing), and input pre-fills with "Test Draft"
      expect(screen.getByText('Test Draft (thing)')).toBeInTheDocument()
    })

    it('updates title preview when e2node title input changes', () => {
      // Reset mock to ensure clean state
      useWriteuptypes.mockReturnValue({
        writeuptypes: [
          { node_id: 1, title: 'thing' },
          { node_id: 2, title: 'idea' },
          { node_id: 3, title: 'person' }
        ],
        selectedWriteuptypeId: 1,
        setSelectedWriteuptypeId: jest.fn()
      })

      render(
        <PublishModal
          draft={{ node_id: 123, title: 'Original' }}
          onSuccess={jest.fn()}
          onClose={jest.fn()}
        />
      )

      const input = screen.getByPlaceholderText(/enter the e2node title/i)
      fireEvent.change(input, { target: { value: 'New Title' } })

      // Title preview should show updated e2node title with writeup type
      expect(screen.getByText('New Title (thing)')).toBeInTheDocument()
    })

    it('updates title preview when writeup type changes', () => {
      const setSelectedWriteuptypeId = jest.fn()

      useWriteuptypes.mockReturnValue({
        writeuptypes: [
          { node_id: 1, title: 'thing' },
          { node_id: 2, title: 'idea' },
          { node_id: 3, title: 'person' }
        ],
        selectedWriteuptypeId: 1,
        setSelectedWriteuptypeId
      })

      const { rerender } = render(
        <PublishModal
          draft={{ node_id: 123, title: 'My Node' }}
          onSuccess={jest.fn()}
          onClose={jest.fn()}
        />
      )

      // Initially shows "My Node (thing)"
      expect(screen.getByText('My Node (thing)')).toBeInTheDocument()

      // Change writeup type to idea
      const select = screen.getByRole('combobox')
      fireEvent.change(select, { target: { value: '2' } })

      // Verify setSelectedWriteuptypeId was called
      expect(setSelectedWriteuptypeId).toHaveBeenCalledWith(2)

      // Update mock to reflect new selection
      useWriteuptypes.mockReturnValue({
        writeuptypes: [
          { node_id: 1, title: 'thing' },
          { node_id: 2, title: 'idea' },
          { node_id: 3, title: 'person' }
        ],
        selectedWriteuptypeId: 2,
        setSelectedWriteuptypeId
      })

      // Rerender with updated state
      rerender(
        <PublishModal
          draft={{ node_id: 123, title: 'My Node' }}
          onSuccess={jest.fn()}
          onClose={jest.fn()}
        />
      )

      // Now should show "My Node (idea)"
      expect(screen.getByText('My Node (idea)')).toBeInTheDocument()
    })

    it('shows draft title as fallback when e2node input is empty', () => {
      // Reset mock to ensure clean state
      useWriteuptypes.mockReturnValue({
        writeuptypes: [
          { node_id: 1, title: 'thing' },
          { node_id: 2, title: 'idea' },
          { node_id: 3, title: 'person' }
        ],
        selectedWriteuptypeId: 1,
        setSelectedWriteuptypeId: jest.fn()
      })

      render(
        <PublishModal
          draft={{ node_id: 123, title: 'Fallback Title' }}
          onSuccess={jest.fn()}
          onClose={jest.fn()}
        />
      )

      const input = screen.getByPlaceholderText(/enter the e2node title/i)
      fireEvent.change(input, { target: { value: '' } })

      // When input is empty, should fall back to showing draft title
      expect(screen.getByText('Fallback Title')).toBeInTheDocument()
    })
  })
})
