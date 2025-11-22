import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import NodeCloner from './NodeCloner'

// Mock react-modal
jest.mock('react-modal', () => {
  return function MockModal({ isOpen, children, contentLabel }) {
    return isOpen ? <div role="dialog" aria-label={contentLabel}>{children}</div> : null
  }
})

global.fetch = jest.fn()

// Mock window.location.href
delete window.location
window.location = { href: '' }

describe('NodeCloner Component', () => {
  beforeEach(() => {
    fetch.mockClear()
    window.location.href = ''
  })

  describe('rendering', () => {
    it('renders the trigger button', () => {
      render(<NodeCloner nodeId={123} nodeTitle="Test Node" nodeType="document" />)
      expect(screen.getByRole('heading', { name: 'Clone Node' })).toBeInTheDocument()
      expect(screen.getByRole('button', { name: 'Clone this document' })).toBeInTheDocument()
    })

    it('displays correct node type in trigger button', () => {
      render(<NodeCloner nodeId={123} nodeTitle="Test Node" nodeType="superdoc" />)
      expect(screen.getByRole('button', { name: 'Clone this superdoc' })).toBeInTheDocument()
    })

    it('modal is closed initially', () => {
      render(<NodeCloner nodeId={123} nodeTitle="Test Node" nodeType="document" />)
      expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
    })

    it('opens modal when trigger button is clicked', () => {
      render(<NodeCloner nodeId={123} nodeTitle="Test Node" nodeType="document" />)
      const triggerButton = screen.getByRole('button', { name: 'Clone this document' })

      fireEvent.click(triggerButton)

      expect(screen.getByRole('dialog')).toBeInTheDocument()
      expect(screen.getByPlaceholderText('Enter new node title...')).toBeInTheDocument()
    })

    it('displays node info in modal', () => {
      render(<NodeCloner nodeId={123} nodeTitle="Test Node" nodeType="document" />)
      const triggerButton = screen.getByRole('button', { name: 'Clone this document' })

      fireEvent.click(triggerButton)

      expect(screen.getByText(/Create a complete copy of/)).toBeInTheDocument()
      expect(screen.getByText(/Test Node \(document\)/)).toBeInTheDocument()
    })

    it('shows helpful note about cloning in modal', () => {
      render(<NodeCloner nodeId={123} nodeTitle="Test Node" nodeType="document" />)
      const triggerButton = screen.getByRole('button', { name: 'Clone this document' })

      fireEvent.click(triggerButton)

      expect(screen.getByText(/The cloned node will have all the same data/)).toBeInTheDocument()
    })

    it('submit button is disabled when input is empty', () => {
      render(<NodeCloner nodeId={123} nodeTitle="Test Node" nodeType="document" />)
      const triggerButton = screen.getByRole('button', { name: 'Clone this document' })

      fireEvent.click(triggerButton)

      const submitButton = screen.getByRole('button', { name: 'Clone Node' })
      expect(submitButton).toBeDisabled()
    })

    it('submit button is enabled when input has text', () => {
      render(<NodeCloner nodeId={123} nodeTitle="Test Node" nodeType="document" />)
      const triggerButton = screen.getByRole('button', { name: 'Clone this document' })

      fireEvent.click(triggerButton)

      const input = screen.getByPlaceholderText('Enter new node title...')
      const submitButton = screen.getByRole('button', { name: 'Clone Node' })

      fireEvent.change(input, { target: { value: 'New Title' } })
      expect(submitButton).not.toBeDisabled()
    })

    it('has Cancel and Clone buttons in modal', () => {
      render(<NodeCloner nodeId={123} nodeTitle="Test Node" nodeType="document" />)
      const triggerButton = screen.getByRole('button', { name: 'Clone this document' })

      fireEvent.click(triggerButton)

      expect(screen.getByRole('button', { name: 'Cancel' })).toBeInTheDocument()
      expect(screen.getByRole('button', { name: 'Clone Node' })).toBeInTheDocument()
    })
  })

  describe('modal interactions', () => {
    it('closes modal when Cancel button is clicked', () => {
      render(<NodeCloner nodeId={123} nodeTitle="Test Node" nodeType="document" />)

      // Open modal
      fireEvent.click(screen.getByRole('button', { name: 'Clone this document' }))
      expect(screen.getByRole('dialog')).toBeInTheDocument()

      // Close modal
      fireEvent.click(screen.getByRole('button', { name: 'Cancel' }))
      expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
    })

    it('clears input when modal is reopened', () => {
      render(<NodeCloner nodeId={123} nodeTitle="Test Node" nodeType="document" />)
      const triggerButton = screen.getByRole('button', { name: 'Clone this document' })

      // Open modal and enter text
      fireEvent.click(triggerButton)
      const input = screen.getByPlaceholderText('Enter new node title...')
      fireEvent.change(input, { target: { value: 'Some text' } })
      expect(input).toHaveValue('Some text')

      // Close modal
      fireEvent.click(screen.getByRole('button', { name: 'Cancel' }))

      // Reopen modal
      fireEvent.click(triggerButton)
      const newInput = screen.getByPlaceholderText('Enter new node title...')
      expect(newInput).toHaveValue('')
    })

    it('clears error when modal is reopened', async () => {
      fetch.mockResolvedValueOnce({
        ok: false,
        json: async () => ({ error: 'Test error' })
      })

      render(<NodeCloner nodeId={123} nodeTitle="Test Node" nodeType="document" />)

      // Open modal, enter text, and submit to get error
      fireEvent.click(screen.getByRole('button', { name: 'Clone this document' }))
      const input = screen.getByPlaceholderText('Enter new node title...')
      fireEvent.change(input, { target: { value: 'Test' } })
      fireEvent.submit(input.closest('form'))

      await waitFor(() => {
        expect(screen.getByText('Test error')).toBeInTheDocument()
      })

      // Close and reopen modal
      fireEvent.click(screen.getByRole('button', { name: 'Cancel' }))
      fireEvent.click(screen.getByRole('button', { name: 'Clone this document' }))

      expect(screen.queryByText('Test error')).not.toBeInTheDocument()
    })
  })

  describe('clone functionality', () => {
    it('clones node successfully and navigates to new node', async () => {
      fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          message: 'Node cloned successfully',
          original_node_id: 123,
          original_title: 'Test Node',
          cloned_node_id: 456,
          cloned_title: 'Cloned Node',
        })
      })

      render(<NodeCloner nodeId={123} nodeTitle="Test Node" nodeType="document" />)

      // Open modal
      fireEvent.click(screen.getByRole('button', { name: 'Clone this document' }))

      const input = screen.getByPlaceholderText('Enter new node title...')
      const submitButton = screen.getByRole('button', { name: 'Clone Node' })

      fireEvent.change(input, { target: { value: 'Cloned Node' } })
      fireEvent.click(submitButton)

      await waitFor(() => {
        expect(fetch).toHaveBeenCalledWith(
          '/api/nodes/123/action/clone',
          expect.objectContaining({
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            credentials: 'include',
            body: JSON.stringify({ title: 'Cloned Node' })
          })
        )
      })

      // Verify navigation to new node
      await waitFor(() => {
        expect(window.location.href).toBe('/?node_id=456')
      })
    })

    it('disables form while submitting', async () => {
      fetch.mockImplementationOnce(() => new Promise(resolve => setTimeout(resolve, 100)))

      render(<NodeCloner nodeId={123} nodeTitle="Test Node" nodeType="document" />)

      // Open modal
      fireEvent.click(screen.getByRole('button', { name: 'Clone this document' }))

      const input = screen.getByPlaceholderText('Enter new node title...')
      const submitButton = screen.getByRole('button', { name: 'Clone Node' })

      fireEvent.change(input, { target: { value: 'Cloned Node' } })
      fireEvent.click(submitButton)

      // Check that input and buttons are disabled during submission
      expect(input).toBeDisabled()
      expect(submitButton).toBeDisabled()
      expect(screen.getByRole('button', { name: 'Cloning...' })).toBeInTheDocument()
      expect(screen.getByRole('button', { name: 'Cancel' })).toBeDisabled()
    })
  })

  describe('error handling', () => {
    it('displays error when API returns error', async () => {
      fetch.mockResolvedValueOnce({
        ok: false,
        json: async () => ({
          error: 'A node with this title already exists'
        })
      })

      render(<NodeCloner nodeId={123} nodeTitle="Test Node" nodeType="document" />)

      // Open modal
      fireEvent.click(screen.getByRole('button', { name: 'Clone this document' }))

      const input = screen.getByPlaceholderText('Enter new node title...')
      fireEvent.change(input, { target: { value: 'Duplicate' } })
      fireEvent.submit(input.closest('form'))

      await waitFor(() => {
        expect(screen.getByText('A node with this title already exists')).toBeInTheDocument()
      })

      // Modal should stay open on error
      expect(screen.getByRole('dialog')).toBeInTheDocument()
    })

    it('displays error when API returns error without message', async () => {
      fetch.mockResolvedValueOnce({
        ok: false,
        json: async () => ({})
      })

      render(<NodeCloner nodeId={123} nodeTitle="Test Node" nodeType="document" />)

      // Open modal
      fireEvent.click(screen.getByRole('button', { name: 'Clone this document' }))

      const input = screen.getByPlaceholderText('Enter new node title...')
      fireEvent.change(input, { target: { value: 'Test' } })
      fireEvent.submit(input.closest('form'))

      await waitFor(() => {
        expect(screen.getByText('Failed to clone node')).toBeInTheDocument()
      })
    })

    it('displays error on network failure', async () => {
      fetch.mockRejectedValueOnce(new Error('Network error'))

      render(<NodeCloner nodeId={123} nodeTitle="Test Node" nodeType="document" />)

      // Open modal
      fireEvent.click(screen.getByRole('button', { name: 'Clone this document' }))

      const input = screen.getByPlaceholderText('Enter new node title...')
      fireEvent.change(input, { target: { value: 'Test' } })
      fireEvent.submit(input.closest('form'))

      await waitFor(() => {
        expect(screen.getByText('Network error: Network error')).toBeInTheDocument()
      })
    })

    it('clears error when submitting again', async () => {
      fetch.mockResolvedValueOnce({
        ok: false,
        json: async () => ({ error: 'First error' })
      })

      render(<NodeCloner nodeId={123} nodeTitle="Test Node" nodeType="document" />)

      // Open modal
      fireEvent.click(screen.getByRole('button', { name: 'Clone this document' }))

      const input = screen.getByPlaceholderText('Enter new node title...')
      fireEvent.change(input, { target: { value: 'Test' } })
      fireEvent.submit(input.closest('form'))

      await waitFor(() => {
        expect(screen.getByText('First error')).toBeInTheDocument()
      })

      // Submit again with successful response
      fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          message: 'Node cloned successfully',
          original_node_id: 123,
          original_title: 'Test Node',
          cloned_node_id: 456,
          cloned_title: 'Success',
        })
      })

      fireEvent.change(input, { target: { value: 'Success' } })
      fireEvent.submit(input.closest('form'))

      await waitFor(() => {
        expect(screen.queryByText('First error')).not.toBeInTheDocument()
      })
    })

    it('re-enables form after error', async () => {
      fetch.mockResolvedValueOnce({
        ok: false,
        json: async () => ({ error: 'Test error' })
      })

      render(<NodeCloner nodeId={123} nodeTitle="Test Node" nodeType="document" />)

      // Open modal
      fireEvent.click(screen.getByRole('button', { name: 'Clone this document' }))

      const input = screen.getByPlaceholderText('Enter new node title...')
      const submitButton = screen.getByRole('button', { name: 'Clone Node' })

      fireEvent.change(input, { target: { value: 'Test' } })
      fireEvent.click(submitButton)

      await waitFor(() => {
        expect(screen.getByText('Test error')).toBeInTheDocument()
      })

      // Form should be re-enabled after error
      expect(input).not.toBeDisabled()
      expect(submitButton).not.toBeDisabled()
    })
  })

  describe('form validation', () => {
    it('does not submit when title is empty', () => {
      render(<NodeCloner nodeId={123} nodeTitle="Test Node" nodeType="document" />)

      // Open modal
      fireEvent.click(screen.getByRole('button', { name: 'Clone this document' }))

      const submitButton = screen.getByRole('button', { name: 'Clone Node' })

      // Input is empty
      fireEvent.click(submitButton)

      expect(fetch).not.toHaveBeenCalled()
    })

    it('does not submit when title is only whitespace', () => {
      render(<NodeCloner nodeId={123} nodeTitle="Test Node" nodeType="document" />)

      // Open modal
      fireEvent.click(screen.getByRole('button', { name: 'Clone this document' }))

      const input = screen.getByPlaceholderText('Enter new node title...')
      const submitButton = screen.getByRole('button', { name: 'Clone Node' })

      fireEvent.change(input, { target: { value: '   ' } })
      fireEvent.click(submitButton)

      expect(fetch).not.toHaveBeenCalled()
    })
  })
})
