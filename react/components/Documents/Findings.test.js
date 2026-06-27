import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
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
    const findings = [{ node_id: 1, title: 'Result 1', type: 'e2node' }]
    render(<Findings data={{ ...defaultProps.data, findings }} user={defaultProps.user} />)
    expect(screen.getByText(/Here's the stuff we found when you searched for "test search"/)).toBeInTheDocument()
  })

  // Regression for #4382 (Tem42): a search with no matches must render the "couldn't find
  // anything" message, not 500. not_found_node now points at Findings (search_results), and
  // Findings renders the empty-results case instead of loading a tombed "Nothing Found" node.
  it('shows the not-found message when there are no results', () => {
    render(<Findings data={{ ...defaultProps.data, findings: [] }} user={defaultProps.user} />)
    expect(screen.getByText(/We couldn't find anything for "test search"/)).toBeInTheDocument()
    expect(screen.queryByText(/Here's the stuff we found/)).not.toBeInTheDocument()
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

  // Migration from op=new to POST /api/node/create (#4340).
  describe('create-node API migration', () => {
    let originalLocation

    beforeEach(() => {
      originalLocation = window.location
      delete window.location
      window.location = { href: '' }
      global.fetch = jest.fn(() =>
        Promise.resolve({ ok: true, json: async () => ({ success: 1, node_id: 999 }) })
      )
    })

    afterEach(() => {
      window.location = originalLocation
      jest.restoreAllMocks()
    })

    const parseBody = (call) => JSON.parse(call[1].body)

    it('creates a draft via /api/node/create and redirects to /node/<id>', async () => {
      render(<Findings data={{ ...defaultProps.data, search_term: 'My Topic' }} user={defaultProps.user} />)

      fireEvent.click(screen.getByRole('button', { name: 'New draft' }))

      await waitFor(() => expect(global.fetch).toHaveBeenCalled())
      const call = global.fetch.mock.calls[0]
      expect(call[0]).toBe('/api/node/create')
      expect(parseBody(call)).toMatchObject({ type: 'draft', title: 'My Topic' })

      await waitFor(() => expect(window.location.href).toBe('/node/999'))
    })

    it('creates an e2node via /api/node/create', async () => {
      render(<Findings data={{ ...defaultProps.data, search_term: 'My Topic' }} user={defaultProps.user} />)

      fireEvent.click(screen.getByRole('button', { name: 'New node' }))

      await waitFor(() => expect(global.fetch).toHaveBeenCalled())
      const call = global.fetch.mock.calls[0]
      expect(call[0]).toBe('/api/node/create')
      expect(parseBody(call)).toMatchObject({ type: 'e2node', title: 'My Topic' })

      await waitFor(() => expect(window.location.href).toBe('/node/999'))
    })

    it('does not call the API when the title is empty', () => {
      render(<Findings data={{ ...defaultProps.data, search_term: '   ' }} user={defaultProps.user} />)

      fireEvent.click(screen.getByRole('button', { name: 'New draft' }))

      expect(global.fetch).not.toHaveBeenCalled()
    })
  })
})
