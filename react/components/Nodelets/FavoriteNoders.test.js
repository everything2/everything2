import React from 'react'
import { render, screen } from '@testing-library/react'
import '@testing-library/jest-dom'
import FavoriteNoders from './FavoriteNoders'

jest.mock('../NodeletContainer', () => {
  return function MockNodeletContainer({ title, children }) {
    return (
      <div data-testid="nodelet-container">
        <div data-testid="nodelet-title">{title}</div>
        <div>{children}</div>
      </div>
    )
  }
})

jest.mock('../LinkNode', () => {
  return function MockLinkNode({ nodeId, title }) {
    return <a data-testid="link-node" data-node-id={nodeId}>{title}</a>
  }
})

describe('FavoriteNoders', () => {
  const mockWriteups = [
    { node_id: 101, title: 'Writeup One', author_id: 201, author_name: 'Author One' },
    { node_id: 102, title: 'Writeup Two', author_id: 202, author_name: 'Author Two' }
  ]

  test('renders title', () => {
    render(<FavoriteNoders favoriteWriteups={mockWriteups} />)
    expect(screen.getByTestId('nodelet-title')).toHaveTextContent('Favorite Noders')
  })

  test('renders all writeups when less than 5', () => {
    render(<FavoriteNoders favoriteWriteups={mockWriteups} />)
    expect(screen.getByText('Writeup One')).toBeInTheDocument()
    expect(screen.getByText('Writeup Two')).toBeInTheDocument()
  })

  test('limits display to 5 writeups when more than 5 provided', () => {
    const manyWriteups = [
      { node_id: 101, title: 'Writeup One', author_id: 201, author_name: 'Author One' },
      { node_id: 102, title: 'Writeup Two', author_id: 202, author_name: 'Author Two' },
      { node_id: 103, title: 'Writeup Three', author_id: 203, author_name: 'Author Three' },
      { node_id: 104, title: 'Writeup Four', author_id: 204, author_name: 'Author Four' },
      { node_id: 105, title: 'Writeup Five', author_id: 205, author_name: 'Author Five' },
      { node_id: 106, title: 'Writeup Six', author_id: 206, author_name: 'Author Six' },
      { node_id: 107, title: 'Writeup Seven', author_id: 207, author_name: 'Author Seven' }
    ]
    render(<FavoriteNoders favoriteWriteups={manyWriteups} />)

    // First 5 should be visible
    expect(screen.getByText('Writeup One')).toBeInTheDocument()
    expect(screen.getByText('Writeup Two')).toBeInTheDocument()
    expect(screen.getByText('Writeup Three')).toBeInTheDocument()
    expect(screen.getByText('Writeup Four')).toBeInTheDocument()
    expect(screen.getByText('Writeup Five')).toBeInTheDocument()

    // 6th and 7th should not be visible
    expect(screen.queryByText('Writeup Six')).not.toBeInTheDocument()
    expect(screen.queryByText('Writeup Seven')).not.toBeInTheDocument()
  })

  test('renders authors', () => {
    render(<FavoriteNoders favoriteWriteups={mockWriteups} />)
    expect(screen.getByText('Author One')).toBeInTheDocument()
    expect(screen.getByText('Author Two')).toBeInTheDocument()
  })

  test('handles empty state', () => {
    render(<FavoriteNoders favoriteWriteups={[]} />)
    expect(screen.getByText(/No favorite writeups available/i)).toBeInTheDocument()
  })
})
