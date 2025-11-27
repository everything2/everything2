import React from 'react'
import { render } from '@testing-library/react'
import NodeList from './NodeList'

jest.mock('../LinkNode', () => {
  return function MockLinkNode({ title, node_id, type, className, anchor }) {
    return (
      <a className={className} data-node-id={node_id} data-type={type} data-anchor={anchor}>
        {title}
      </a>
    )
  }
})

describe('NodeList', () => {
  const mockWriteups = [
    {
      node_id: 1001,
      parent_id: 2001,
      parent_title: 'Test E2Node 1',
      writeuptype: 'idea',
      publishtime: '2025-11-26 10:00:00',
      author_id: 3001,
      author_name: 'alice',
      notnew: 0
    },
    {
      node_id: 1002,
      parent_id: 2002,
      parent_title: 'Test E2Node 2',
      writeuptype: 'person',
      publishtime: '2025-11-26 09:00:00',
      author_id: 3002,
      author_name: 'bob',
      notnew: 1
    }
  ]

  const mockUser = {
    isEditor: false
  }

  it('renders page title for 25', () => {
    const mockData = {
      type: '25',
      nodelist: mockWriteups,
      records: 25,
      currentPage: '25'
    }
    const { getByText } = render(<NodeList data={mockData} user={mockUser} />)
    expect(getByText('25 Most Recent Writeups')).toBeInTheDocument()
  })

  it('renders page title for everything_new_nodes', () => {
    const mockData = {
      type: 'everything_new_nodes',
      nodelist: mockWriteups,
      records: 100,
      currentPage: 'Everything New Nodes'
    }
    const { getByText } = render(<NodeList data={mockData} user={mockUser} />)
    expect(getByText('Everything New Nodes (100)')).toBeInTheDocument()
  })

  it('renders page title for e2n', () => {
    const mockData = {
      type: 'e2n',
      nodelist: mockWriteups,
      records: 200,
      currentPage: 'E2N'
    }
    const { getByText } = render(<NodeList data={mockData} user={mockUser} />)
    expect(getByText('E2N - Everything2 New (200)')).toBeInTheDocument()
  })

  it('renders page size selector', () => {
    const mockData = {
      type: '25',
      nodelist: mockWriteups,
      records: 25,
      currentPage: '25'
    }
    const { getByLabelText } = render(<NodeList data={mockData} user={mockUser} />)
    const selector = getByLabelText('Show:')
    expect(selector).toBeInTheDocument()
    expect(selector).toHaveValue('25')
  })

  it('renders all writeups', () => {
    const mockData = {
      type: '25',
      nodelist: mockWriteups,
      records: 25,
      currentPage: '25'
    }
    const { getByText, container } = render(<NodeList data={mockData} user={mockUser} />)
    expect(getByText('Test E2Node 1')).toBeInTheDocument()
    expect(getByText('Test E2Node 2')).toBeInTheDocument()

    // Check that e2node links are present
    const e2nodeLinks = container.querySelectorAll('a[href^="/e2node/"]')
    expect(e2nodeLinks.length).toBeGreaterThanOrEqual(2)

    // Check that writeup anchor links are present
    expect(getByText('(idea)')).toBeInTheDocument()
    expect(getByText('(person)')).toBeInTheDocument()
  })

  it('renders author names', () => {
    const mockData = {
      type: '25',
      nodelist: mockWriteups,
      records: 25,
      currentPage: '25'
    }
    const { getByText } = render(<NodeList data={mockData} user={mockUser} />)
    expect(getByText('alice')).toBeInTheDocument()
    expect(getByText('bob')).toBeInTheDocument()
  })

  it('renders publish dates', () => {
    const mockData = {
      type: '25',
      nodelist: mockWriteups,
      records: 25,
      currentPage: '25'
    }
    const { getByText } = render(<NodeList data={mockData} user={mockUser} />)
    expect(getByText('2025-11-26 10:00:00')).toBeInTheDocument()
    expect(getByText('2025-11-26 09:00:00')).toBeInTheDocument()
  })

  it('does not show hide buttons for non-editors', () => {
    const mockData = {
      type: '25',
      nodelist: mockWriteups,
      records: 25,
      currentPage: '25'
    }
    const { queryByText } = render(<NodeList data={mockData} user={mockUser} />)
    expect(queryByText('(h?)')).not.toBeInTheDocument()
    expect(queryByText('(un-h!)')).not.toBeInTheDocument()
  })

  it('shows hide buttons for editors', () => {
    const mockData = {
      type: '25',
      nodelist: mockWriteups,
      records: 25,
      currentPage: '25'
    }
    const editorUser = { isEditor: true }
    const { getByText } = render(<NodeList data={mockData} user={editorUser} />)
    expect(getByText('(h?)')).toBeInTheDocument()
    expect(getByText('(un-h!)')).toBeInTheDocument()
  })

  it('shows correct hide/unhide text based on notnew status', () => {
    const mockData = {
      type: '25',
      nodelist: mockWriteups,
      records: 25,
      currentPage: '25'
    }
    const editorUser = { isEditor: true }
    const { getByText } = render(<NodeList data={mockData} user={editorUser} />)
    // First writeup: notnew=0 → show (h?)
    expect(getByText('(h?)')).toBeInTheDocument()
    // Second writeup: notnew=1 → show (un-h!)
    expect(getByText('(un-h!)')).toBeInTheDocument()
  })

  it('renders empty state', () => {
    const mockData = {
      type: '25',
      nodelist: [],
      records: 25,
      currentPage: '25'
    }
    const { getByText } = render(<NodeList data={mockData} user={mockUser} />)
    expect(getByText('No writeups found.')).toBeInTheDocument()
  })

  it('renders Writeups by Type link', () => {
    const mockData = {
      type: '25',
      nodelist: mockWriteups,
      records: 25,
      currentPage: '25'
    }
    const { getByText } = render(<NodeList data={mockData} user={mockUser} />)
    expect(getByText('Writeups by Type')).toBeInTheDocument()
  })

  it('renders all page size options in selector', () => {
    const mockData = {
      type: '25',
      nodelist: mockWriteups,
      records: 25,
      currentPage: '25'
    }
    const { getByText } = render(<NodeList data={mockData} user={mockUser} />)
    const selector = getByText('25').closest('select')
    expect(selector).toBeInTheDocument()
    expect(selector.querySelectorAll('option')).toHaveLength(5)
  })

  it('applies striped row styling', () => {
    const mockData = {
      type: '25',
      nodelist: mockWriteups,
      records: 25,
      currentPage: '25'
    }
    const { container } = render(<NodeList data={mockData} user={mockUser} />)
    const rows = container.querySelectorAll('tbody tr')
    expect(rows[0]).toHaveStyle({ backgroundColor: '#f8f9fa' })
    expect(rows[1]).toHaveStyle({ backgroundColor: 'transparent' })
  })

  it('handles missing user gracefully', () => {
    const mockData = {
      type: '25',
      nodelist: mockWriteups,
      records: 25,
      currentPage: '25'
    }
    const { getByText } = render(<NodeList data={mockData} user={null} />)
    expect(getByText('Test E2Node 1')).toBeInTheDocument()
  })

  it('generates correct e2node and writeup anchor links', () => {
    const mockData = {
      type: '25',
      nodelist: mockWriteups,
      records: 25,
      currentPage: '25'
    }
    const { container } = render(<NodeList data={mockData} user={mockUser} />)

    // Check e2node links point directly to /e2node/title
    const e2nodeLinks = container.querySelectorAll('a[href^="/e2node/"]')
    expect(e2nodeLinks[0]).toHaveAttribute('href', '/e2node/Test%20E2Node%201')
    expect(e2nodeLinks[1]).toHaveAttribute('href', '/e2node/Test%20E2Node%202')

    // Check writeup type links include anchor to specific author
    const writeupLinks = container.querySelectorAll('a[href*="#"]')
    expect(writeupLinks[0]).toHaveAttribute('href', '/title/Test%20E2Node%201#alice')
    expect(writeupLinks[1]).toHaveAttribute('href', '/title/Test%20E2Node%202#bob')
  })
})
