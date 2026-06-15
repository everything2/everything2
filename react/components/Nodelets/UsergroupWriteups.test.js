import React from 'react'
import { render, screen, fireEvent } from '@testing-library/react'
import UsergroupWriteups from './UsergroupWriteups'

// Mock child components
jest.mock('../NodeletContainer', () => {
  return function NodeletContainer({ title, children }) {
    return (
      <div data-testid="nodelet-container">
        <h3>{title}</h3>
        {children}
      </div>
    )
  }
})

jest.mock('../LinkNode', () => {
  return function LinkNode({ nodeId, title }) {
    return <a data-testid="link-node">{title || `Node ${nodeId}`}</a>
  }
})

describe('UsergroupWriteups', () => {
  const mockData = {
    currentGroup: { node_id: 123, title: 'E2science' },
    writeups: [
      { node_id: 456, title: 'Quantum Mechanics 101' },
      { node_id: 789, title: 'String Theory Explained' }
    ],
    availableGroups: [
      { node_id: 123, title: 'E2science' },
      { node_id: 999, title: 'E2arts' }
    ],
    isRestricted: false,
    isEditor: false
  }

  // Payload the content endpoint returns when switching to E2arts (node 999).
  const e2artsData = {
    currentGroup: { node_id: 999, title: 'E2arts' },
    writeups: [{ node_id: 111, title: 'Impressionism' }],
    availableGroups: mockData.availableGroups,
    isRestricted: false,
    isEditor: false
  }

  beforeEach(() => {
    global.fetch = jest.fn((url) => {
      if (typeof url === 'string' && url.includes('/api/usergroups/')) {
        return Promise.resolve({
          ok: true,
          json: () => Promise.resolve({ success: 1, usergroupData: e2artsData })
        })
      }
      // /api/preferences/set
      return Promise.resolve({ ok: true, json: () => Promise.resolve({}) })
    })
  })

  afterEach(() => {
    jest.resetAllMocks()
  })

  test('shows friendly message when usergroupData is undefined', () => {
    render(<UsergroupWriteups usergroupData={undefined} />)

    expect(screen.getByText('No usergroup data available')).toBeInTheDocument()
  })

  test('shows friendly message when usergroupData is null', () => {
    render(<UsergroupWriteups usergroupData={null} />)

    expect(screen.getByText('No usergroup data available')).toBeInTheDocument()
  })

  test('renders usergroup title and writeups', () => {
    render(<UsergroupWriteups usergroupData={mockData} />)

    const e2scienceElements = screen.getAllByText('E2science')
    expect(e2scienceElements.length).toBeGreaterThan(0)
    expect(screen.getByText('Quantum Mechanics 101')).toBeInTheDocument()
    expect(screen.getByText('String Theory Explained')).toBeInTheDocument()
  })

  test('uses the shared infolist display (matching New Writeups, not the old bold linklist)', () => {
    const { container } = render(<UsergroupWriteups usergroupData={mockData} />)

    const list = container.querySelector('ul.usergroup-writeups__list')
    expect(list).toBeInTheDocument()
    expect(list).toHaveClass('infolist')
    expect(list).not.toHaveClass('linklist')
  })

  test('renders dropdown with available groups', () => {
    render(<UsergroupWriteups usergroupData={mockData} />)

    const select = screen.getByRole('combobox')
    expect(select).toBeInTheDocument()

    const options = screen.getAllByRole('option')
    expect(options).toHaveLength(2)
    expect(options[0]).toHaveValue('E2science')
    expect(options[1]).toHaveValue('E2arts')
  })

  test('on group change: updates the selection, persists the preference, and repaints in place (no full reload)', async () => {
    render(<UsergroupWriteups usergroupData={mockData} />)

    const select = screen.getByRole('combobox')
    fireEvent.change(select, { target: { value: 'E2arts' } })

    // Selection reflects the choice immediately
    expect(select.value).toBe('E2arts')

    // Persists the choice as a user preference
    expect(global.fetch).toHaveBeenCalledWith(
      '/api/preferences/set',
      expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({ nodeletusergroup: 'E2arts' })
      })
    )

    // Fetches the new group's writeups by id (for the in-place repaint)
    expect(global.fetch).toHaveBeenCalledWith(
      '/api/usergroups/999/writeups',
      expect.objectContaining({ credentials: 'include' })
    )

    // The nodelet repaints with the new group's writeups without a page reload
    expect(await screen.findByText('Impressionism')).toBeInTheDocument()
    expect(screen.queryByText('Quantum Mechanics 101')).not.toBeInTheDocument()
  })

  test('shows "No writeups available" when writeups list is empty', () => {
    const emptyData = { ...mockData, writeups: [] }
    render(<UsergroupWriteups usergroupData={emptyData} />)

    expect(screen.getByText('No writeups available')).toBeInTheDocument()
  })

  test('shows restricted message when restricted and user is not editor', () => {
    const restrictedData = { ...mockData, isRestricted: true, isEditor: false }
    render(<UsergroupWriteups usergroupData={restrictedData} />)

    expect(screen.getByText('This usergroup is restricted')).toBeInTheDocument()
  })

  test('shows content when restricted but user is editor', () => {
    const restrictedData = { ...mockData, isRestricted: true, isEditor: true }
    render(<UsergroupWriteups usergroupData={restrictedData} />)

    const e2scienceElements = screen.getAllByText('E2science')
    expect(e2scienceElements.length).toBeGreaterThan(0)
  })

  test('does not show dropdown when availableGroups is empty', () => {
    const noGroupsData = { ...mockData, availableGroups: [] }
    render(<UsergroupWriteups usergroupData={noGroupsData} />)

    expect(screen.queryByRole('combobox')).not.toBeInTheDocument()
  })
})
