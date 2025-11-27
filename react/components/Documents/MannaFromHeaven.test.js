import React from 'react'
import { render } from '@testing-library/react'
import MannaFromHeaven from './MannaFromHeaven'

// Mock LinkNode component
jest.mock('../LinkNode', () => {
  return function MockLinkNode({ title }) {
    return <span>{title}</span>
  }
})

describe('MannaFromHeaven', () => {
  const mockData = {
    type: 'manna_from_heaven',
    numdays: 30,
    writeups: [
      { username: 'Alice', user_id: 1, count: 5 },
      { username: 'Bob', user_id: 2, count: 10 },
      { username: 'Charlie', user_id: 3, count: 3 }
    ]
  }

  it('renders the page title', () => {
    const { getByText } = render(<MannaFromHeaven data={mockData} />)
    expect(getByText('Manna from Heaven')).toBeInTheDocument()
  })

  it('renders the time period description', () => {
    const { getByText } = render(<MannaFromHeaven data={mockData} />)
    expect(getByText(/over the last 30 days/)).toBeInTheDocument()
  })

  it('renders all user writeup counts', () => {
    const { getByText } = render(<MannaFromHeaven data={mockData} />)
    
    expect(getByText('Alice')).toBeInTheDocument()
    expect(getByText('Bob')).toBeInTheDocument()
    expect(getByText('Charlie')).toBeInTheDocument()
  })

  it('displays correct writeup counts', () => {
    const { container } = render(<MannaFromHeaven data={mockData} />)
    const rows = container.querySelectorAll('tbody tr')
    
    expect(rows).toHaveLength(3)
    expect(rows[0]).toHaveTextContent('5')
    expect(rows[1]).toHaveTextContent('10')
    expect(rows[2]).toHaveTextContent('3')
  })

  it('calculates and displays total writeups', () => {
    const { getByText } = render(<MannaFromHeaven data={mockData} />)
    
    // Total should be 5 + 10 + 3 = 18
    expect(getByText('Total writeups: 18')).toBeInTheDocument()
  })

  it('displays total in table footer', () => {
    const { container } = render(<MannaFromHeaven data={mockData} />)
    const footer = container.querySelector('tfoot tr')
    
    expect(footer).toHaveTextContent('Total')
    expect(footer).toHaveTextContent('18')
  })

  it('renders time period filter links', () => {
    const { getByText } = render(<MannaFromHeaven data={mockData} />)

    expect(getByText('7 days')).toHaveAttribute('href', '/title/Manna+from+heaven?days=7')
    expect(getByText('30 days')).toHaveAttribute('href', '/title/Manna+from+heaven?days=30')
    expect(getByText('90 days')).toHaveAttribute('href', '/title/Manna+from+heaven?days=90')
    expect(getByText('365 days')).toHaveAttribute('href', '/title/Manna+from+heaven?days=365')
  })

  it('renders table headers', () => {
    const { getByText } = render(<MannaFromHeaven data={mockData} />)
    
    expect(getByText('User')).toBeInTheDocument()
    expect(getByText('Writeups')).toBeInTheDocument()
  })

  it('handles empty writeups array', () => {
    const emptyData = { type: 'manna_from_heaven', numdays: 30, writeups: [] }
    const { getByText, container } = render(<MannaFromHeaven data={emptyData} />)
    
    // Should still render title
    expect(getByText('Manna from Heaven')).toBeInTheDocument()
    
    // Total should be 0
    expect(getByText('Total writeups: 0')).toBeInTheDocument()
    
    // No data rows
    const rows = container.querySelectorAll('tbody tr')
    expect(rows).toHaveLength(0)
  })

  it('displays different time periods correctly', () => {
    const data90Days = { ...mockData, numdays: 90 }
    const { getByText } = render(<MannaFromHeaven data={data90Days} />)
    
    expect(getByText(/over the last 90 days/)).toBeInTheDocument()
  })
})
