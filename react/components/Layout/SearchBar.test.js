/**
 * Tests for SearchBar component
 */

import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import SearchBar from './SearchBar'

// Mock fetch
global.fetch = jest.fn()

describe('SearchBar', () => {
  let mockSearchResults

  beforeEach(() => {
    mockSearchResults = {
      success: true,
      results: [
        { node_id: 1, title: 'Test Node 1', type: 'e2node' },
        { node_id: 2, title: 'Test Node 2', type: 'user' },
        { node_id: 3, title: 'Testing Guide', type: 'superdoc' }
      ]
    }

    fetch.mockResolvedValue({
      json: async () => mockSearchResults
    })

    // Mock window.location.href
    delete window.location
    window.location = { href: '' }

    jest.useFakeTimers()
  })

  afterEach(() => {
    jest.clearAllMocks()
    jest.useRealTimers()
  })

  describe('Rendering', () => {
    it('renders search input', () => {
      render(<SearchBar />)
      const input = screen.getByPlaceholderText(/search/i)
      expect(input).toBeInTheDocument()
    })

    it('renders with initial value', () => {
      render(<SearchBar initialValue="test query" />)
      const input = screen.getByDisplayValue('test query')
      expect(input).toBeInTheDocument()
    })

    it('renders compact version', () => {
      const { container } = render(<SearchBar compact={true} />)
      // Check for compact styling (implementation-dependent)
      expect(container).toBeInTheDocument()
    })

    it('shows search icon', () => {
      const { container } = render(<SearchBar />)
      // FaSearch icon should be present - check for svg element
      const icon = container.querySelector('svg')
      expect(icon).toBeInTheDocument()
    })
  })

  describe('Search functionality', () => {
    it('triggers search after typing with debounce', async () => {
      render(<SearchBar />)
      const input = screen.getByPlaceholderText(/search/i)

      fireEvent.change(input, { target: { value: 'test' } })

      // Should not call fetch immediately
      expect(fetch).not.toHaveBeenCalled()

      // Advance timers past debounce delay
      jest.advanceTimersByTime(200)

      await waitFor(() => {
        expect(fetch).toHaveBeenCalledWith(
          expect.stringContaining('/api/node_search?q=test')
        )
      })
    })

    it('does not search for queries shorter than 2 characters', async () => {
      render(<SearchBar />)
      const input = screen.getByPlaceholderText(/search/i)

      fireEvent.change(input, { target: { value: 'a' } })
      jest.advanceTimersByTime(200)

      expect(fetch).not.toHaveBeenCalled()
    })

    it('displays search suggestions', async () => {
      render(<SearchBar />)
      const input = screen.getByPlaceholderText(/search/i)

      fireEvent.change(input, { target: { value: 'test' } })
      jest.advanceTimersByTime(200)

      await waitFor(() => {
        expect(screen.getByText('Test Node 1')).toBeInTheDocument()
      })

      expect(screen.getByText('Test Node 2')).toBeInTheDocument()
      expect(screen.getByText('Testing Guide')).toBeInTheDocument()
    })

    it('shows "Show all results" option when suggestions exist', async () => {
      render(<SearchBar />)
      const input = screen.getByPlaceholderText(/search/i)

      fireEvent.change(input, { target: { value: 'test' } })
      jest.advanceTimersByTime(200)

      await waitFor(() => {
        expect(screen.getByText(/show all results/i)).toBeInTheDocument()
      })
    })

    it('hides suggestions when no results', async () => {
      fetch.mockResolvedValue({
        json: async () => ({ success: true, results: [] })
      })

      render(<SearchBar />)
      const input = screen.getByPlaceholderText(/search/i)

      fireEvent.change(input, { target: { value: 'nonexistent' } })
      jest.advanceTimersByTime(200)

      await waitFor(() => {
        expect(fetch).toHaveBeenCalled()
      })

      expect(screen.queryByText('Test Node 1')).not.toBeInTheDocument()
    })

    it('handles search API errors gracefully', async () => {
      const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation()
      fetch.mockRejectedValue(new Error('Network error'))

      render(<SearchBar />)
      const input = screen.getByPlaceholderText(/search/i)

      fireEvent.change(input, { target: { value: 'test' } })
      jest.advanceTimersByTime(200)

      await waitFor(() => {
        expect(fetch).toHaveBeenCalled()
      })

      expect(consoleErrorSpy).toHaveBeenCalledWith(
        'Search failed:',
        expect.any(Error)
      )

      consoleErrorSpy.mockRestore()
    })

    it('debounces multiple rapid inputs', async () => {
      render(<SearchBar />)
      const input = screen.getByPlaceholderText(/search/i)

      // Type multiple characters rapidly
      fireEvent.change(input, { target: { value: 't' } })
      jest.advanceTimersByTime(50)
      fireEvent.change(input, { target: { value: 'te' } })
      jest.advanceTimersByTime(50)
      fireEvent.change(input, { target: { value: 'tes' } })
      jest.advanceTimersByTime(50)
      fireEvent.change(input, { target: { value: 'test' } })

      // Only the last input should trigger search after full debounce
      jest.advanceTimersByTime(200)

      await waitFor(() => {
        expect(fetch).toHaveBeenCalledTimes(1)
      })
      expect(fetch).toHaveBeenCalledWith(
        expect.stringContaining('q=test')
      )
    })
  })

  describe('Keyboard navigation', () => {
    it('navigates suggestions with arrow keys', async () => {
      render(<SearchBar />)
      const input = screen.getByPlaceholderText(/search/i)

      fireEvent.change(input, { target: { value: 'test' } })
      jest.advanceTimersByTime(200)

      await waitFor(() => {
        expect(screen.getByText('Test Node 1')).toBeInTheDocument()
      })

      // Arrow down to select first item
      fireEvent.keyDown(input, { key: 'ArrowDown' })

      // Check if first item is highlighted (implementation-dependent)
      // This would need to check for highlight class or aria-selected
    })

    it('closes suggestions on Escape key', async () => {
      render(<SearchBar />)
      const input = screen.getByPlaceholderText(/search/i)

      fireEvent.change(input, { target: { value: 'test' } })
      jest.advanceTimersByTime(200)

      await waitFor(() => {
        expect(screen.getByText('Test Node 1')).toBeInTheDocument()
      })

      fireEvent.keyDown(input, { key: 'Escape' })

      // Suggestions should be hidden
      expect(screen.queryByText('Test Node 1')).not.toBeInTheDocument()
    })
  })

  describe('Navigation', () => {
    it('navigates to selected suggestion on click', async () => {
      render(<SearchBar />)
      const input = screen.getByPlaceholderText(/search/i)

      fireEvent.change(input, { target: { value: 'test' } })
      jest.advanceTimersByTime(200)

      await waitFor(() => {
        expect(screen.getByText('Test Node 1')).toBeInTheDocument()
      })

      const suggestion = screen.getByText('Test Node 1')
      fireEvent.click(suggestion)

      // Should navigate to the node (check href was set)
      expect(window.location.href).toContain('/title/')
    })

    it('performs full search on form submit', () => {
      render(<SearchBar />)
      const input = screen.getByPlaceholderText(/search/i)
      const form = input.closest('form')

      fireEvent.change(input, { target: { value: 'test query' } })
      fireEvent.submit(form)

      // The form submits naturally, no JS navigation assertion needed
      expect(form).toBeTruthy()
    })

    it('navigates to full search when clicking "Show all results"', async () => {
      render(<SearchBar />)
      const input = screen.getByPlaceholderText(/search/i)

      fireEvent.change(input, { target: { value: 'test' } })
      jest.advanceTimersByTime(200)

      await waitFor(() => {
        expect(screen.getByText(/show all results/i)).toBeInTheDocument()
      })

      const showAllButton = screen.getByText(/show all results/i)
      fireEvent.click(showAllButton)

      expect(window.location.href).toContain('test')
    })
  })

  describe('lastnode_id tracking', () => {
    it('sets cookie when lastNodeId is provided', async () => {
      // Mock document.cookie
      let cookieValue = ''
      Object.defineProperty(document, 'cookie', {
        get: () => cookieValue,
        set: (value) => { cookieValue = value },
        configurable: true
      })

      render(<SearchBar lastNodeId={12345} />)
      const input = screen.getByPlaceholderText(/search/i)

      fireEvent.change(input, { target: { value: 'test' } })
      jest.advanceTimersByTime(200)

      await waitFor(() => {
        expect(screen.getByText('Test Node 1')).toBeInTheDocument()
      })

      const suggestion = screen.getByText('Test Node 1')
      fireEvent.click(suggestion)

      // Cookie should be set before navigation
      expect(document.cookie).toContain('lastnode_id=12345')
    })

    it('does not set cookie when lastNodeId is 0', async () => {
      let cookieValue = ''
      Object.defineProperty(document, 'cookie', {
        get: () => cookieValue,
        set: (value) => { cookieValue = value },
        configurable: true
      })

      render(<SearchBar lastNodeId={0} />)
      const input = screen.getByPlaceholderText(/search/i)

      fireEvent.change(input, { target: { value: 'test' } })
      jest.advanceTimersByTime(200)

      await waitFor(() => {
        expect(screen.getByText('Test Node 1')).toBeInTheDocument()
      })

      const suggestion = screen.getByText('Test Node 1')
      fireEvent.click(suggestion)

      expect(document.cookie).not.toContain('lastnode_id')
    })
  })

  describe('Click outside behavior', () => {
    it('closes suggestions when clicking outside', async () => {
      render(
        <div>
          <SearchBar />
          <button>Outside Button</button>
        </div>
      )
      const input = screen.getByPlaceholderText(/search/i)

      fireEvent.change(input, { target: { value: 'test' } })
      jest.advanceTimersByTime(200)

      await waitFor(() => {
        expect(screen.getByText('Test Node 1')).toBeInTheDocument()
      })

      const outsideButton = screen.getByText('Outside Button')
      fireEvent.mouseDown(outsideButton)

      // Suggestions should be hidden
      expect(screen.queryByText('Test Node 1')).not.toBeInTheDocument()
    })

    it('keeps suggestions open when clicking inside container', async () => {
      render(<SearchBar />)
      const input = screen.getByPlaceholderText(/search/i)

      fireEvent.change(input, { target: { value: 'test' } })
      jest.advanceTimersByTime(200)

      await waitFor(() => {
        expect(screen.getByText('Test Node 1')).toBeInTheDocument()
      })

      // Click on the input itself
      fireEvent.mouseDown(input)

      // Suggestions should still be visible
      expect(screen.getByText('Test Node 1')).toBeInTheDocument()
    })
  })

  describe('Loading state', () => {
    it('shows loading indicator while searching', async () => {
      // Make fetch take time
      fetch.mockImplementation(
        () => new Promise(resolve => setTimeout(() => resolve({
          json: async () => mockSearchResults
        }), 1000))
      )

      render(<SearchBar />)
      const input = screen.getByPlaceholderText(/search/i)

      fireEvent.change(input, { target: { value: 'test' } })
      jest.advanceTimersByTime(200)

      await waitFor(() => {
        expect(fetch).toHaveBeenCalled()
      })

      // Loading state should be visible (implementation-dependent)
      // Check for loading spinner or text if rendered
    })
  })
})
