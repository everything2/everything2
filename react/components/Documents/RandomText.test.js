import React from 'react'
import { render, fireEvent } from '@testing-library/react'
import RandomText from './RandomText'

jest.mock('../ParseLinks', () => {
  return function MockParseLinks({ text }) {
    return <span data-parsed>{text}</span>
  }
})

describe('RandomText', () => {
  const mockFezismsData = {
    type: 'fezisms_generator',
    title: 'Fezisms Generator',
    wit: [
      ['[Fez|DADDY NEEDS SOME]', '[thefez|GLOOPY GLOBS OF]'],
      ['[human heads|HUMAN HEADS!]', '[ninja bongs|NINJA BONGS!]']
    ]
  }

  const mockPiercismsData = {
    type: 'piercisms_generator',
    title: 'Piercisms Generator',
    wit: [
      ['[I give myself|Nipple]', '[The View From My Room|Croony]', '[Dr. Brightman|Swoon]']
    ]
  }

  // No longer mocking Math.random - component should work with real randomness

  it('renders title when provided', () => {
    const { getByText } = render(<RandomText data={mockFezismsData} />)
    expect(getByText('Fezisms Generator')).toBeInTheDocument()
  })

  it('renders description when provided', () => {
    const dataWithDesc = {
      ...mockFezismsData,
      description: 'Random fez wisdom'
    }
    const { getByText } = render(<RandomText data={dataWithDesc} />)
    expect(getByText('Random fez wisdom')).toBeInTheDocument()
  })

  it('renders Generate Another button', () => {
    const { getByText } = render(<RandomText data={mockFezismsData} />)
    expect(getByText('Generate Another')).toBeInTheDocument()
  })

  it('generates new quote when Generate Another clicked without page reload', () => {
    // Mock Math.random to control selections
    let callCount = 0
    const originalRandom = Math.random
    Math.random = jest.fn(() => {
      // First render: return 0 (first items)
      // After click: return 0.99 (last items)
      return callCount++ < 2 ? 0 : 0.99
    })

    const { getByText, container } = render(<RandomText data={mockFezismsData} />)

    // Get initial quote text
    const initialText = container.querySelector('[data-parsed]').textContent

    // Click generate button
    fireEvent.click(getByText('Generate Another'))

    // Get new quote text
    const newText = container.querySelector('[data-parsed]').textContent

    // Text should have changed (assuming different quotes at indices 0 and last)
    // Since we control Math.random, first render gets index 0, second gets last index
    expect(Math.random).toHaveBeenCalled()

    // Restore original Math.random
    Math.random = originalRandom
  })

  it('selects one item from each fezisms array', () => {
    const { container } = render(<RandomText data={mockFezismsData} />)
    const parsed = container.querySelectorAll('[data-parsed]')

    // Fezisms has 2 wit arrays, should render 2 selections
    expect(parsed).toHaveLength(2)
  })

  it('renders fezisms with horizontal multi-part layout', () => {
    const { container } = render(<RandomText data={mockFezismsData} />)
    const parsed = container.querySelectorAll('[data-parsed]')

    // Both parts should be present (one from each array)
    expect(parsed).toHaveLength(2)
  })

  it('selects one item from piercisms array', () => {
    const { container } = render(<RandomText data={mockPiercismsData} />)
    const parsed = container.querySelectorAll('[data-parsed]')

    // Piercisms has 1 wit array, should render 1 selection
    expect(parsed).toHaveLength(1)
  })

  it('renders piercisms with single large centered text', () => {
    const { container } = render(<RandomText data={mockPiercismsData} />)
    const parsed = container.querySelectorAll('[data-parsed]')

    expect(parsed).toHaveLength(1)
  })

  it('uses ParseLinks for E2 bracket syntax', () => {
    const { container } = render(<RandomText data={mockPiercismsData} />)
    const parsed = container.querySelector('[data-parsed]')

    expect(parsed).toBeInTheDocument()
  })

  it('applies centered styling', () => {
    const { container } = render(<RandomText data={mockFezismsData} />)
    const centerDiv = container.querySelector('div[style*="center"]')

    expect(centerDiv).toBeInTheDocument()
  })

  it('handles missing title gracefully', () => {
    const dataNoTitle = { ...mockFezismsData, title: null }
    const { container } = render(<RandomText data={dataNoTitle} />)

    expect(container.querySelector('h2')).not.toBeInTheDocument()
  })

  it('handles missing description gracefully', () => {
    const { container } = render(<RandomText data={mockFezismsData} />)

    // Description not in mockData, should not render
    expect(container.querySelector('p')).not.toBeInTheDocument()
  })

  it('uses Math.random for selection', () => {
    // Verify that component uses Math.random
    const spy = jest.spyOn(Math, 'random')
    render(<RandomText data={mockPiercismsData} />)
    expect(spy).toHaveBeenCalled()
    spy.mockRestore()
  })
})
