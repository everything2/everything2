import React from 'react'
import { render, screen } from '@testing-library/react'
import { E2IdleHandler } from './E2IdleHandler'

// Mock react-idle-timer
jest.mock('react-idle-timer', () => ({
  withIdleTimer: (Component) => {
    // Return a wrapper that passes through props and adds idle timer props
    return function WrappedComponent(props) {
      return <Component {...props} isIdle={false} />
    }
  }
}))

describe('E2IdleHandler', () => {
  it('renders children', () => {
    render(
      <E2IdleHandler>
        <div>Child content</div>
      </E2IdleHandler>
    )
    expect(screen.getByText('Child content')).toBeInTheDocument()
  })

  it('renders multiple children', () => {
    render(
      <E2IdleHandler>
        <div>First child</div>
        <div>Second child</div>
      </E2IdleHandler>
    )
    expect(screen.getByText('First child')).toBeInTheDocument()
    expect(screen.getByText('Second child')).toBeInTheDocument()
  })

  it('renders nested children', () => {
    render(
      <E2IdleHandler>
        <div>
          <span>Nested content</span>
        </div>
      </E2IdleHandler>
    )
    expect(screen.getByText('Nested content')).toBeInTheDocument()
  })

  it('handles no children', () => {
    const { container } = render(<E2IdleHandler />)
    expect(container.firstChild).toBeNull()
  })
})
