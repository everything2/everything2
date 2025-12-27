import React from 'react'
import { render, screen } from '@testing-library/react'
import WhatDoesWhat from './WhatDoesWhat'

// Mock LinkNode component
jest.mock('../LinkNode', () => {
  return function MockLinkNode({ display, id, title }) {
    return <a data-testid="link-node" href={`/node/${id}`}>{display || title || id}</a>
  }
})

// Mock ParseLinks component
jest.mock('../ParseLinks', () => {
  return function MockParseLinks({ text }) {
    return <span data-testid="parse-links">{text}</span>
  }
})

describe('WhatDoesWhat', () => {
  const mockData = {
    sections: [
      {
        type: 'superdoc',
        nodes: [
          { node_id: 101, title: 'Sign Up', documentation: 'The document where you sign up for a new user account.' },
          { node_id: 102, title: 'Settings', documentation: null }
        ],
        docSettingId: 1001
      },
      {
        type: 'oppressor_superdoc',
        nodes: [
          { node_id: 201, title: 'Admin Tool', documentation: 'Admin-only tool' }
        ],
        docSettingId: 1002
      }
    ],
    mainDocSettingId: 999,
    isAdmin: true
  }

  it('renders section headers for each type', () => {
    render(<WhatDoesWhat data={mockData} />)

    const headings = screen.getAllByRole('heading')
    expect(headings.length).toBe(2)
    expect(headings[0]).toHaveTextContent('superdoc')
    expect(headings[1]).toHaveTextContent('oppressor_superdoc')
  })

  it('renders nodes within each section', () => {
    render(<WhatDoesWhat data={mockData} />)

    expect(screen.getByText('Sign Up')).toBeInTheDocument()
    expect(screen.getByText('Settings')).toBeInTheDocument()
    expect(screen.getByText('Admin Tool')).toBeInTheDocument()
  })

  it('shows documentation when available', () => {
    render(<WhatDoesWhat data={mockData} />)

    expect(screen.getByText('The document where you sign up for a new user account.')).toBeInTheDocument()
  })

  it('shows "none" in italics when no documentation', () => {
    render(<WhatDoesWhat data={mockData} />)

    expect(screen.getByText('none')).toBeInTheDocument()
    expect(screen.getByText('none').tagName).toBe('EM')
  })

  it('shows node IDs', () => {
    render(<WhatDoesWhat data={mockData} />)

    expect(screen.getByText('(101)')).toBeInTheDocument()
    expect(screen.getByText('(102)')).toBeInTheDocument()
  })

  it('shows edit links for admins', () => {
    render(<WhatDoesWhat data={mockData} />)

    // Main edit link
    expect(screen.getByText('edit/add documentation')).toBeInTheDocument()

    // Section edit links
    const editLinks = screen.getAllByText('edit documentation')
    expect(editLinks.length).toBe(2)
  })

  it('hides edit links for non-admins', () => {
    const nonAdminData = {
      ...mockData,
      isAdmin: false
    }

    render(<WhatDoesWhat data={nonAdminData} />)

    expect(screen.queryByText('edit/add documentation')).not.toBeInTheDocument()
    expect(screen.queryByText('edit documentation')).not.toBeInTheDocument()
  })

  it('shows error message when access denied', () => {
    const errorData = { error: 'Access denied' }

    render(<WhatDoesWhat data={errorData} />)

    expect(screen.getByText('Access denied')).toBeInTheDocument()
  })

  it('renders alternating row classes', () => {
    const { container } = render(<WhatDoesWhat data={mockData} />)

    const rows = container.querySelectorAll('tr')
    // First row should have oddrow class (index 0 is even, so className is oddrow)
    expect(rows[0]).toHaveClass('oddrow')
    // Second row should not have oddrow class
    expect(rows[1]).not.toHaveClass('oddrow')
  })

  it('parses E2 links in documentation text', () => {
    const dataWithLinks = {
      sections: [
        {
          type: 'superdoc',
          nodes: [
            { node_id: 101, title: 'ENN', documentation: 'An [ENN]-style listing with 25 as the default' }
          ],
          docSettingId: 1001
        }
      ],
      mainDocSettingId: 999,
      isAdmin: true
    }

    render(<WhatDoesWhat data={dataWithLinks} />)

    // ParseLinks component should receive the documentation text
    const parsedContent = screen.getByTestId('parse-links')
    expect(parsedContent).toHaveTextContent('An [ENN]-style listing with 25 as the default')
  })
})
