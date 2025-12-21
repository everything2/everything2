import React from 'react'
import { render, screen } from '@testing-library/react'
import ExperienceGain from './ExperienceGain'

describe('ExperienceGain', () => {
  it('renders nothing when amount is null', () => {
    const { container } = render(<ExperienceGain amount={null} />)
    expect(container).toBeEmptyDOMElement()
  })

  it('renders nothing when amount is undefined', () => {
    const { container } = render(<ExperienceGain />)
    expect(container).toBeEmptyDOMElement()
  })

  it('renders nothing when amount is 0', () => {
    const { container } = render(<ExperienceGain amount={0} />)
    expect(container).toBeEmptyDOMElement()
  })

  it('renders nothing when amount is negative', () => {
    const { container } = render(<ExperienceGain amount={-5} />)
    expect(container).toBeEmptyDOMElement()
  })

  it('renders singular point message for amount of 1', () => {
    render(<ExperienceGain amount={1} />)
    expect(screen.getByText('1')).toBeInTheDocument()
    expect(screen.getByText(/gained/)).toBeInTheDocument()
    expect(screen.getByText(/experience point!/)).toBeInTheDocument()
  })

  it('renders plural points message for amount greater than 1', () => {
    render(<ExperienceGain amount={5} />)
    expect(screen.getByText('5')).toBeInTheDocument()
    expect(screen.getByText(/gained/)).toBeInTheDocument()
    expect(screen.getByText(/experience points!/)).toBeInTheDocument()
  })

  it('displays the amount in bold', () => {
    render(<ExperienceGain amount={10} />)
    const strongElement = screen.getByText('10')
    expect(strongElement.tagName).toBe('STRONG')
  })

  it('renders the "gained" link to node tracker', () => {
    render(<ExperienceGain amount={5} />)
    const gainedLink = screen.getByText('gained')
    expect(gainedLink).toHaveAttribute('href', '/node/superdoc/node tracker')
  })
})
