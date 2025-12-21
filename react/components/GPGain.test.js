import React from 'react'
import { render, screen } from '@testing-library/react'
import GPGain from './GPGain'

describe('GPGain', () => {
  it('renders nothing when amount is null', () => {
    const { container } = render(<GPGain amount={null} />)
    expect(container).toBeEmptyDOMElement()
  })

  it('renders nothing when amount is undefined', () => {
    const { container } = render(<GPGain />)
    expect(container).toBeEmptyDOMElement()
  })

  it('renders nothing when amount is 0', () => {
    const { container } = render(<GPGain amount={0} />)
    expect(container).toBeEmptyDOMElement()
  })

  it('renders nothing when amount is negative', () => {
    const { container } = render(<GPGain amount={-5} />)
    expect(container).toBeEmptyDOMElement()
  })

  it('renders singular GP message for amount of 1', () => {
    render(<GPGain amount={1} />)
    expect(screen.getByText('1')).toBeInTheDocument()
    expect(screen.getByText(/Yay! You gained/)).toBeInTheDocument()
    expect(screen.getByText(/GP\./)).toBeInTheDocument()
  })

  it('renders plural GP message for amount greater than 1', () => {
    render(<GPGain amount={5} />)
    expect(screen.getByText('5')).toBeInTheDocument()
    expect(screen.getByText(/Yay! You gained/)).toBeInTheDocument()
    expect(screen.getByText(/GP!/)).toBeInTheDocument()
  })

  it('displays the amount in bold', () => {
    render(<GPGain amount={10} />)
    const strongElement = screen.getByText('10')
    expect(strongElement.tagName).toBe('STRONG')
  })
})
