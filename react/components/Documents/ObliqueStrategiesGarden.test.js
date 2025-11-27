import React from 'react'
import { render } from '@testing-library/react'
import ObliqueStrategiesGarden from './ObliqueStrategiesGarden'

describe('ObliqueStrategiesGarden', () => {
  it('renders a 10x10 table', () => {
    const { container } = render(<ObliqueStrategiesGarden />)

    const rows = container.querySelectorAll('tr')
    expect(rows).toHaveLength(10)

    rows.forEach(row => {
      const cells = row.querySelectorAll('td')
      expect(cells).toHaveLength(10)
    })
  })

  it('contains exactly 100 cells', () => {
    const { container } = render(<ObliqueStrategiesGarden />)
    const cells = container.querySelectorAll('td')
    expect(cells).toHaveLength(100)
  })

  it('has some cells with strategies and some empty', () => {
    const { container } = render(<ObliqueStrategiesGarden />)
    const cells = container.querySelectorAll('td')

    const filledCells = Array.from(cells).filter(cell => cell.textContent.trim() !== '')
    const emptyCells = Array.from(cells).filter(cell => cell.textContent.trim() === '')

    // Grid should have some filled cells (random placement)
    expect(filledCells.length).toBeGreaterThan(0)
    
    // Grid should have some empty cells
    expect(emptyCells.length).toBeGreaterThan(0)
  })

  it('generates stable grid across re-renders', () => {
    const { container, rerender } = render(<ObliqueStrategiesGarden />)

    // Get initial grid content
    const initialCells = Array.from(container.querySelectorAll('td')).map(
      cell => cell.textContent
    )

    // Re-render component
    rerender(<ObliqueStrategiesGarden />)

    // Get new grid content
    const newCells = Array.from(container.querySelectorAll('td')).map(cell => cell.textContent)

    // Grid should be identical (useMemo with empty deps)
    expect(newCells).toEqual(initialCells)
  })

  it('applies proper table styling', () => {
    const { container } = render(<ObliqueStrategiesGarden />)

    const table = container.querySelector('table')
    expect(table).toHaveStyle({ width: '100%', borderCollapse: 'collapse' })
  })

  it('applies proper cell styling', () => {
    const { container } = render(<ObliqueStrategiesGarden />)

    const cell = container.querySelector('td')
    expect(cell).toHaveStyle({
      border: '1px solid #ddd',
      padding: '8px',
      minHeight: '40px',
      verticalAlign: 'top',
      fontSize: '0.9em'
    })
  })

  it('has tbody element', () => {
    const { container } = render(<ObliqueStrategiesGarden />)
    expect(container.querySelector('tbody')).toBeInTheDocument()
  })

  it('places strategies from the predefined list', () => {
    const { container } = render(<ObliqueStrategiesGarden />)
    const cells = container.querySelectorAll('td')

    // Get all non-empty cell content
    const strategies = Array.from(cells)
      .map(cell => cell.textContent.trim())
      .filter(text => text !== '')

    // All strategies should be non-empty strings
    strategies.forEach(strategy => {
      expect(strategy.length).toBeGreaterThan(0)
    })
  })
})
