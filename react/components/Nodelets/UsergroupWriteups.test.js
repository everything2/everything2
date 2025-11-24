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

  test('renders dropdown with available groups', () => {
    render(<UsergroupWriteups usergroupData={mockData} />)

    const select = screen.getByRole('combobox')
    expect(select).toBeInTheDocument()

    const options = screen.getAllByRole('option')
    expect(options).toHaveLength(2)
    expect(options[0]).toHaveValue('E2science')
    expect(options[1]).toHaveValue('E2arts')
  })

  test('allows changing selected group', () => {
    render(<UsergroupWriteups usergroupData={mockData} />)

    const select = screen.getByRole('combobox')
    fireEvent.change(select, { target: { value: 'E2arts' } })

    expect(select.value).toBe('E2arts')
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
