import React from 'react'
import { render, screen } from '@testing-library/react'
import ServerTime from './ServerTime'

describe('ServerTime', () => {
  it('renders nothing when timeString is null', () => {
    const { container } = render(<ServerTime timeString={null} />)
    expect(container).toBeEmptyDOMElement()
  })

  it('renders nothing when timeString is undefined', () => {
    const { container } = render(<ServerTime />)
    expect(container).toBeEmptyDOMElement()
  })

  it('renders nothing when timeString is empty', () => {
    const { container } = render(<ServerTime timeString="" />)
    expect(container).toBeEmptyDOMElement()
  })

  it('renders server time only when showLocalTime is false', () => {
    render(<ServerTime timeString="12:34:56" showLocalTime={false} />)
    expect(screen.getByText('Server time:')).toBeInTheDocument()
    expect(screen.getByText('12:34:56')).toBeInTheDocument()
    expect(screen.queryByText('Your time:')).not.toBeInTheDocument()
  })

  it('renders server time only when localTimeString is not provided', () => {
    render(<ServerTime timeString="12:34:56" showLocalTime={true} />)
    expect(screen.getByText('Server time:')).toBeInTheDocument()
    expect(screen.getByText('12:34:56')).toBeInTheDocument()
    expect(screen.queryByText('Your time:')).not.toBeInTheDocument()
  })

  it('renders both server and local time when both are provided and showLocalTime is true', () => {
    const { container } = render(
      <ServerTime
        timeString="12:34:56"
        showLocalTime={true}
        localTimeString="08:34:56"
      />
    )
    expect(screen.getByText('Server time:')).toBeInTheDocument()
    expect(screen.getByText('Your time:')).toBeInTheDocument()
    // Check full text content since times are rendered as text nodes
    expect(container.textContent).toContain('12:34:56')
    expect(container.textContent).toContain('08:34:56')
  })

  it('renders labels in bold', () => {
    render(
      <ServerTime
        timeString="12:34:56"
        showLocalTime={true}
        localTimeString="08:34:56"
      />
    )
    const serverLabel = screen.getByText('Server time:')
    const localLabel = screen.getByText('Your time:')
    expect(serverLabel.tagName).toBe('STRONG')
    expect(localLabel.tagName).toBe('STRONG')
  })
})
