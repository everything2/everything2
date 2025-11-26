import React from 'react'
import { render, screen } from '@testing-library/react'
import '@testing-library/jest-dom'
import E2Staff from './E2Staff'

// Mock ParseLinks component
jest.mock('../ParseLinks', () => {
  return function ParseLinks({ text }) {
    return <span>{text}</span>
  }
})

// Mock LinkNode component
jest.mock('../LinkNode', () => {
  return function LinkNode({ title, type, node_id }) {
    return <a href={`/node/${type}/${node_id}`}>{title}</a>
  }
})

describe('E2Staff Component', () => {
  const mockData = {
    editors: [
      { title: 'editor1', node_id: 1001, type: 'user' },
      { title: 'editor2', node_id: 1002, type: 'user' },
    ],
    gods: [
      { title: 'god1', node_id: 2001, type: 'user' },
      { title: 'god2', node_id: 2002, type: 'user' },
    ],
    inactive: [
      { title: 'inactive_god', node_id: 2003, type: 'user' },
    ],
    sigtitle: [
      { title: 'sigtitle_user', node_id: 3001, type: 'user' },
    ],
    chanops: [
      { title: 'chanop1', node_id: 4001, type: 'user' },
      { title: 'chanop2', node_id: 4002, type: 'user' },
    ],
  }

  test('renders all main sections', () => {
    const { container } = render(<E2Staff data={mockData} />)

    expect(container.textContent).toMatch(/Content Editor.*Usergroup/)
    expect(container.textContent).toMatch(/gods.*usergroup/)
    expect(container.textContent).toMatch(/Who does what/)
    expect(container.textContent).toMatch(/Chanops/)
  })

  test('displays editor list', () => {
    const { container } = render(<E2Staff data={mockData} />)

    expect(container.textContent).toMatch(/editor1/)
    expect(container.textContent).toMatch(/editor2/)
  })

  test('displays gods list with active and inactive sections', () => {
    const { container } = render(<E2Staff data={mockData} />)

    // Active gods
    expect(container.textContent).toMatch(/god1/)
    expect(container.textContent).toMatch(/god2/)

    // Inactive gods
    expect(container.textContent).toMatch(/inactive_god/)
  })

  test('displays chanops list', () => {
    const { container } = render(<E2Staff data={mockData} />)

    expect(container.textContent).toMatch(/chanop1/)
    expect(container.textContent).toMatch(/chanop2/)
  })

  test('displays sigtitle users', () => {
    const { container } = render(<E2Staff data={mockData} />)

    expect(container.textContent).toMatch(/sigtitle_user/)
  })

  test('explains staff symbols correctly', () => {
    const { container } = render(<E2Staff data={mockData} />)

    expect(container.textContent).toMatch(/\$/) // Content Editor symbol
    expect(container.textContent).toMatch(/@/) // Gods symbol
    expect(container.textContent).toMatch(/\+/) // Chanops symbol
  })

  test('lists site leadership', () => {
    const { container } = render(<E2Staff data={mockData} />)

    expect(container.textContent).toMatch(/jaybonci/)
    expect(container.textContent).toMatch(/Tem42/)
    expect(container.textContent).toMatch(/mauler/)
  })

  test('displays correct number of editor list items', () => {
    const { container } = render(<E2Staff data={mockData} />)

    // Find all list items that contain editor links
    const editorLinks = container.querySelectorAll('a[href*="/node/user/1001"], a[href*="/node/user/1002"]')
    expect(editorLinks.length).toBe(2)
  })

  test('renders with empty lists gracefully', () => {
    const emptyData = {
      editors: [],
      gods: [],
      inactive: [],
      sigtitle: [],
      chanops: [],
    }

    const { container } = render(<E2Staff data={emptyData} />)

    // Should still render main headings
    expect(container.textContent).toMatch(/Content Editor.*Usergroup/)
    expect(container.textContent).toMatch(/gods.*usergroup/)
  })

  test('uses LinkNode for all user links', () => {
    const { container } = render(<E2Staff data={mockData} />)

    // Check that all users are rendered as links with correct format
    const userLinks = container.querySelectorAll('a[href^="/node/user/"]')
    expect(userLinks.length).toBeGreaterThan(0)
  })

  test('includes explanation of editor powers', () => {
    const { container } = render(<E2Staff data={mockData} />)

    expect(container.textContent).toMatch(/power to remove things from New Writeups/)
    expect(container.textContent).toMatch(/can actually edit the text of any writeup/)
  })

  test('includes explanation of god powers', () => {
    const { container } = render(<E2Staff data={mockData} />)

    expect(container.textContent).toMatch(/Gods have all the powers/)
    expect(container.textContent).toMatch(/power to bless a user/)
    expect(container.textContent).toMatch(/can delete an entire node/)
  })

  test('clarifies what gods cannot do', () => {
    const { container } = render(<E2Staff data={mockData} />)

    expect(container.textContent).toMatch(/members of the gods group/)
    expect(container.textContent).toMatch(/cannot/)
    expect(container.textContent).toMatch(/Vote on any given writeup more than once/)
    expect(container.textContent).toMatch(/Vote on their own writeups/)
  })
})
