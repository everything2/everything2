import React from 'react'
import { render, screen, fireEvent } from '@testing-library/react'
import NodeletContainer from './NodeletContainer'

describe('NodeletContainer', () => {
  const defaultProps = {
    id: 'test-nodelet',
    title: 'Test Nodelet',
    nodeletIsOpen: true
  }

  it('renders with the correct id', () => {
    const { container } = render(
      <NodeletContainer {...defaultProps}>
        <div>Content</div>
      </NodeletContainer>
    )
    expect(container.querySelector('#test-nodelet')).toBeInTheDocument()
  })

  it('renders with nodelet class', () => {
    const { container } = render(
      <NodeletContainer {...defaultProps}>
        <div>Content</div>
      </NodeletContainer>
    )
    expect(container.querySelector('.nodelet')).toBeInTheDocument()
  })

  it('renders title as h2', () => {
    render(
      <NodeletContainer {...defaultProps}>
        <div>Content</div>
      </NodeletContainer>
    )
    // The h2 has role="button" so check using getByText
    expect(screen.getByText('Test Nodelet')).toBeInTheDocument()
  })

  it('renders children inside nodelet_content', () => {
    const { container } = render(
      <NodeletContainer {...defaultProps}>
        <div data-testid="child-content">Child Content</div>
      </NodeletContainer>
    )
    expect(screen.getByTestId('child-content')).toBeInTheDocument()
    expect(container.querySelector('.nodelet_content')).toContainElement(screen.getByTestId('child-content'))
  })

  it('shows content when nodeletIsOpen is true', () => {
    render(
      <NodeletContainer {...defaultProps} nodeletIsOpen={true}>
        <div>Visible Content</div>
      </NodeletContainer>
    )
    expect(screen.getByText('Visible Content')).toBeInTheDocument()
  })

  it('calls showNodelet with true when opening', () => {
    const showNodelet = jest.fn()
    render(
      <NodeletContainer {...defaultProps} nodeletIsOpen={false} showNodelet={showNodelet}>
        <div>Content</div>
      </NodeletContainer>
    )

    // Click the trigger button to open
    fireEvent.click(screen.getByRole('button', { name: 'Test Nodelet' }))

    expect(showNodelet).toHaveBeenCalledWith('Test Nodelet', true)
  })

  it('calls showNodelet with false when closing', () => {
    const showNodelet = jest.fn()
    render(
      <NodeletContainer {...defaultProps} nodeletIsOpen={true} showNodelet={showNodelet}>
        <div>Content</div>
      </NodeletContainer>
    )

    // Click the trigger button to close
    fireEvent.click(screen.getByRole('button', { name: 'Test Nodelet' }))

    expect(showNodelet).toHaveBeenCalledWith('Test Nodelet', false)
  })

  it('does not crash when showNodelet is not provided', () => {
    render(
      <NodeletContainer {...defaultProps} showNodelet={undefined}>
        <div>Content</div>
      </NodeletContainer>
    )

    // Click the trigger button (which is styled as h2) - should not throw
    fireEvent.click(screen.getByRole('button', { name: 'Test Nodelet' }))

    expect(screen.getByText('Content')).toBeInTheDocument()
  })

  it('renders multiple children', () => {
    render(
      <NodeletContainer {...defaultProps}>
        <div>First child</div>
        <div>Second child</div>
      </NodeletContainer>
    )
    expect(screen.getByText('First child')).toBeInTheDocument()
    expect(screen.getByText('Second child')).toBeInTheDocument()
  })
})
