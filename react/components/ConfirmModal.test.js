import React from 'react'
import { render, screen, fireEvent } from '@testing-library/react'
import ConfirmModal from './ConfirmModal'

describe('ConfirmModal', () => {
  const defaultProps = {
    isOpen: true,
    onClose: jest.fn(),
    onConfirm: jest.fn(),
    message: 'Are you sure?'
  }

  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('visibility', () => {
    it('renders nothing when isOpen is false', () => {
      const { container } = render(<ConfirmModal {...defaultProps} isOpen={false} />)
      expect(container).toBeEmptyDOMElement()
    })

    it('renders modal when isOpen is true', () => {
      render(<ConfirmModal {...defaultProps} />)
      expect(screen.getByText('Are you sure?')).toBeInTheDocument()
    })
  })

  describe('default props', () => {
    it('uses default title "Confirm"', () => {
      render(<ConfirmModal {...defaultProps} />)
      expect(screen.getByRole('heading', { name: 'Confirm' })).toBeInTheDocument()
    })

    it('uses default confirm button text "Confirm"', () => {
      render(<ConfirmModal {...defaultProps} />)
      expect(screen.getByRole('button', { name: 'Confirm' })).toBeInTheDocument()
    })

    it('uses default cancel button text "Cancel"', () => {
      render(<ConfirmModal {...defaultProps} />)
      expect(screen.getByRole('button', { name: 'Cancel' })).toBeInTheDocument()
    })
  })

  describe('custom props', () => {
    it('displays custom title', () => {
      render(<ConfirmModal {...defaultProps} title="Delete Item" />)
      expect(screen.getByText('Delete Item')).toBeInTheDocument()
    })

    it('displays custom message', () => {
      render(<ConfirmModal {...defaultProps} message="This action cannot be undone." />)
      expect(screen.getByText('This action cannot be undone.')).toBeInTheDocument()
    })

    it('displays custom confirm button text', () => {
      render(<ConfirmModal {...defaultProps} confirmText="Yes, delete" />)
      expect(screen.getByRole('button', { name: 'Yes, delete' })).toBeInTheDocument()
    })

    it('displays custom cancel button text', () => {
      render(<ConfirmModal {...defaultProps} cancelText="No, keep it" />)
      expect(screen.getByRole('button', { name: 'No, keep it' })).toBeInTheDocument()
    })
  })

  describe('interactions', () => {
    it('calls onConfirm and onClose when confirm button is clicked', () => {
      const onConfirm = jest.fn()
      const onClose = jest.fn()

      render(<ConfirmModal {...defaultProps} onConfirm={onConfirm} onClose={onClose} />)

      fireEvent.click(screen.getByRole('button', { name: 'Confirm' }))

      expect(onConfirm).toHaveBeenCalledTimes(1)
      expect(onClose).toHaveBeenCalledTimes(1)
    })

    it('calls only onClose when cancel button is clicked', () => {
      const onConfirm = jest.fn()
      const onClose = jest.fn()

      render(<ConfirmModal {...defaultProps} onConfirm={onConfirm} onClose={onClose} />)

      fireEvent.click(screen.getByRole('button', { name: 'Cancel' }))

      expect(onConfirm).not.toHaveBeenCalled()
      expect(onClose).toHaveBeenCalledTimes(1)
    })

    it('calls onClose when clicking on the backdrop', () => {
      const onClose = jest.fn()

      render(<ConfirmModal {...defaultProps} onClose={onClose} />)

      // Find the backdrop overlay element by class
      const backdrop = document.querySelector('.nodelet-modal-overlay')
      fireEvent.click(backdrop)

      expect(onClose).toHaveBeenCalledTimes(1)
    })

    it('does not close when clicking on modal content', () => {
      const onClose = jest.fn()

      render(<ConfirmModal {...defaultProps} onClose={onClose} />)

      // Click on the modal content itself (the message div)
      const modalContent = screen.getByText('Are you sure?')
      fireEvent.click(modalContent)

      expect(onClose).not.toHaveBeenCalled()
    })
  })

  describe('styling', () => {
    it('uses modal-compact CSS classes', () => {
      render(<ConfirmModal {...defaultProps} title="Delete" />)

      const title = screen.getByRole('heading', { name: 'Delete' })
      expect(title).toHaveClass('modal-compact__title')
    })
  })
})
