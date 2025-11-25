import React from 'react'
import { render, screen } from '@testing-library/react'
import '@testing-library/jest-dom'
import RecentNodes from './RecentNodes'

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

describe('RecentNodes', () => {
  const mockNodes = [
    { node_id: 101, title: 'Node One' },
    { node_id: 102, title: 'Node Two' },
    { node_id: 103, title: 'Node Three' }
  ]

  test('renders title', () => {
    render(<RecentNodes recentNodes={mockNodes} />)
    expect(screen.getByTestId('nodelet-title')).toHaveTextContent('Recent Nodes')
  })

  test('renders all recent nodes', () => {
    render(<RecentNodes recentNodes={mockNodes} />)
    expect(screen.getByText('Node One')).toBeInTheDocument()
    expect(screen.getByText('Node Two')).toBeInTheDocument()
    expect(screen.getByText('Node Three')).toBeInTheDocument()
  })

  test('renders random saying', () => {
    const { container } = render(<RecentNodes recentNodes={mockNodes} />)
    const em = container.querySelector('em')
    expect(em).toBeInTheDocument()
    expect(em.textContent).toMatch(/:$/)
  })

  test('renders erase trail button', () => {
    render(<RecentNodes recentNodes={mockNodes} />)
    const button = screen.getByRole('button')
    expect(button).toBeInTheDocument()
  })

  test('form has submit button', () => {
    const { container } = render(<RecentNodes recentNodes={mockNodes} />)
    const button = container.querySelector('input[type="submit"][name="schwammdrueber"]')
    expect(button).toBeInTheDocument()
  })

  test('renders empty state with saying only', () => {
    render(<RecentNodes recentNodes={[]} />)
    const { container } = render(<RecentNodes recentNodes={[]} />)
    expect(container.querySelector('ol')).not.toBeInTheDocument()
    expect(container.querySelector('form')).not.toBeInTheDocument()
  })

  test('handles undefined nodes', () => {
    render(<RecentNodes />)
    expect(screen.getByTestId('nodelet-container')).toBeInTheDocument()
  })

  test('renders as ordered list', () => {
    const { container } = render(<RecentNodes recentNodes={mockNodes} />)
    expect(container.querySelector('ol')).toBeInTheDocument()
  })
})
