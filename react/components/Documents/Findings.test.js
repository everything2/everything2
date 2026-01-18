import React from 'react'
import { render, screen } from '@testing-library/react'
import Findings from './Findings'

// Mock the GoogleAds component
jest.mock('../Layout/GoogleAds', () => ({
  InContentAd: ({ show }) => show ? <div data-testid="in-content-ad">Ad</div> : null
}))

describe('Findings', () => {
  const defaultProps = {
    data: {
      search_term: 'test search',
      findings: [],
      lastnode_id: 12345,
      is_guest: false,
      has_excerpts: false
    },
    user: { node_id: 123 }
  }

  it('renders search term message', () => {
    render(<Findings {...defaultProps} />)
    expect(screen.getByText(/Here's the stuff we found when you searched for "test search"/)).toBeInTheDocument()
  })

  it('renders findings list', () => {
    const findings = [
      { node_id: 1, title: 'Result 1', type: 'e2node' },
      { node_id: 2, title: 'Result 2', type: 'e2node' }
    ]
    render(<Findings data={{ ...defaultProps.data, findings }} user={defaultProps.user} />)
    expect(screen.getByText('Result 1')).toBeInTheDocument()
    expect(screen.getByText('Result 2')).toBeInTheDocument()
  })

  it('shows nodeshell styling for nodeshells', () => {
    const findings = [
      { node_id: 1, title: 'Nodeshell', type: 'e2node', is_nodeshell: true }
    ]
    const { container } = render(<Findings data={{ ...defaultProps.data, findings }} user={defaultProps.user} />)
    expect(container.querySelector('.findings-item--nodeshell')).toBeInTheDocument()
  })

  it('shows excerpts when available', () => {
    const findings = [
      { node_id: 1, title: 'Result', type: 'e2node', excerpt: 'This is an excerpt' }
    ]
    render(<Findings data={{ ...defaultProps.data, findings }} user={defaultProps.user} />)
    expect(screen.getByText('This is an excerpt')).toBeInTheDocument()
  })

  it('shows writeup count when multiple', () => {
    const findings = [
      { node_id: 1, title: 'Result', type: 'e2node', writeup_count: 5 }
    ]
    render(<Findings data={{ ...defaultProps.data, findings }} user={defaultProps.user} />)
    expect(screen.getByText('(5 entries)')).toBeInTheDocument()
  })

  it('shows type for non-e2node results', () => {
    const findings = [
      { node_id: 1, title: 'User Result', type: 'user' }
    ]
    render(<Findings data={{ ...defaultProps.data, findings }} user={defaultProps.user} />)
    expect(screen.getByText('(user)')).toBeInTheDocument()
  })

  describe('ads for guests', () => {
    it('shows ads every 4 items for guests', () => {
      const findings = Array.from({ length: 10 }, (_, i) => ({
        node_id: i + 1,
        title: `Result ${i + 1}`,
        type: 'e2node'
      }))
      render(<Findings data={{ ...defaultProps.data, findings, is_guest: true }} user={defaultProps.user} />)
      // Ads should appear after items 4 and 8 (not after last item)
      const ads = screen.getAllByTestId('in-content-ad')
      expect(ads).toHaveLength(2)
    })

    it('does not show ads for logged-in users', () => {
      const findings = Array.from({ length: 10 }, (_, i) => ({
        node_id: i + 1,
        title: `Result ${i + 1}`,
        type: 'e2node'
      }))
      render(<Findings data={{ ...defaultProps.data, findings, is_guest: false }} user={defaultProps.user} />)
      expect(screen.queryByTestId('in-content-ad')).not.toBeInTheDocument()
    })

    it('does not show ad after last item', () => {
      const findings = Array.from({ length: 4 }, (_, i) => ({
        node_id: i + 1,
        title: `Result ${i + 1}`,
        type: 'e2node'
      }))
      render(<Findings data={{ ...defaultProps.data, findings, is_guest: true }} user={defaultProps.user} />)
      // With exactly 4 items, no ad should show (would be at the end)
      expect(screen.queryByTestId('in-content-ad')).not.toBeInTheDocument()
    })

    it('shows ad after 4th item when there are more', () => {
      const findings = Array.from({ length: 5 }, (_, i) => ({
        node_id: i + 1,
        title: `Result ${i + 1}`,
        type: 'e2node'
      }))
      render(<Findings data={{ ...defaultProps.data, findings, is_guest: true }} user={defaultProps.user} />)
      expect(screen.getAllByTestId('in-content-ad')).toHaveLength(1)
    })
  })

  describe('no search term', () => {
    it('shows message when no search term', () => {
      render(<Findings data={{ no_search_term: true, message: 'Please enter a search term' }} user={defaultProps.user} />)
      expect(screen.getByText('Please enter a search term')).toBeInTheDocument()
    })

    it('shows link to random nodes', () => {
      render(<Findings data={{ no_search_term: true, message: 'No search term' }} user={defaultProps.user} />)
      expect(screen.getByRole('link', { name: 'Visit Random Nodes' })).toBeInTheDocument()
    })
  })

  describe('create new section', () => {
    it('shows guest message for guests', () => {
      render(<Findings data={{ ...defaultProps.data, is_guest: true }} user={defaultProps.user} />)
      expect(screen.getByText(/Since we didn't find what you were looking for, you can search again:/)).toBeInTheDocument()
    })

    it('shows create options for logged-in users', () => {
      render(<Findings data={{ ...defaultProps.data, is_guest: false }} user={defaultProps.user} />)
      expect(screen.getByRole('button', { name: 'New draft' })).toBeInTheDocument()
      expect(screen.getByRole('button', { name: 'New node' })).toBeInTheDocument()
    })

    it('hides create options for guests', () => {
      render(<Findings data={{ ...defaultProps.data, is_guest: true }} user={defaultProps.user} />)
      expect(screen.queryByRole('button', { name: 'New draft' })).not.toBeInTheDocument()
      expect(screen.queryByRole('button', { name: 'New node' })).not.toBeInTheDocument()
    })
  })
})
