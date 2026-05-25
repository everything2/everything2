import React from 'react'
import { render, screen } from '@testing-library/react'
import UserDisplay from './UserDisplay'

// Mock child components that pull in network/state we don't care about for
// date-rendering tests.
jest.mock('../LinkNode', () => function MockLinkNode({ title, display }) {
  return <span>{display || title}</span>
})
jest.mock('../MessageBox', () => function MockMessageBox() { return null })
jest.mock('../UserToolsModal', () => function MockUserToolsModal() { return null })
jest.mock('../TimeSince', () => function MockTimeSince() { return null })
jest.mock('../Editor/E2HtmlSanitizer', () => ({
  renderE2Content: (text) => ({ html: text || '' }),
}))

const baseProps = {
  e2: { user: { guest: false, title: 'viewer' } },
  data: {
    user: {
      node_id: 1,
      title: 'Oolong',
      createtime: '2001-04-14T23:28:51Z', // The actual production timestamp from the bug
      lasttime: '2026-05-10T16:02:27Z',
      categories: [],
      groups: [],
      doctext: '',
    },
    viewer: { is_editor: false },
    is_own: false,
    is_ignored: 0,
    is_infected: false,
    message_count: 0,
    recent_writeup_count: 0,
  },
}

describe('UserDisplay date formatting (issue #4056)', () => {
  it('renders user createtime as the UTC calendar date, not the viewer\'s local-TZ date', () => {
    render(<UserDisplay {...baseProps} />)
    // 2001-04-14T23:28:51Z is April 14 in UTC. Pre-fix, viewers east of UTC
    // saw "April 15" because toLocaleDateString defaulted to local TZ.
    expect(screen.getByText(/April 14, 2001/)).toBeInTheDocument()
  })

  it('renders lasttime in UTC as well', () => {
    render(<UserDisplay {...baseProps} />)
    // 2026-05-10T16:02:27Z is May 10 in UTC.
    expect(screen.getByText(/May 10, 2026/)).toBeInTheDocument()
  })

  it('handles edge-of-day UTC timestamps consistently for all viewers', () => {
    // 23:59:00 UTC on April 14: viewers anywhere from UTC-23 to UTC+0 would
    // see April 14 as their local day, but anyone east of UTC would see
    // April 15 with the old behavior. With timeZone:'UTC' it's always April 14.
    const edgeProps = {
      ...baseProps,
      data: {
        ...baseProps.data,
        user: { ...baseProps.data.user, createtime: '2001-04-14T23:59:00Z' },
      },
    }
    render(<UserDisplay {...edgeProps} />)
    expect(screen.getByText(/April 14, 2001/)).toBeInTheDocument()
  })

  it('renders "forever" for null createtime', () => {
    const noDateProps = {
      ...baseProps,
      data: {
        ...baseProps.data,
        user: { ...baseProps.data.user, createtime: null, lasttime: null },
      },
    }
    render(<UserDisplay {...noDateProps} />)
    // formatDate(null) returns <em>forever</em>
    const forevers = screen.getAllByText('forever')
    expect(forevers.length).toBeGreaterThan(0)
    expect(forevers[0].tagName).toBe('EM')
  })

  it('renders "forever" for epoch 0 / invalid date', () => {
    const epochProps = {
      ...baseProps,
      data: {
        ...baseProps.data,
        user: {
          ...baseProps.data.user,
          createtime: '1970-01-01T00:00:00Z',
          lasttime: 'not a date',
        },
      },
    }
    render(<UserDisplay {...epochProps} />)
    const forevers = screen.getAllByText('forever')
    expect(forevers.length).toBeGreaterThan(0)
  })
})

// Regression coverage for the React-vs-Perl truthy bug pattern: viewer
// flags arrive from the server as 0/1 numbers, not JS booleans. A bare
// `{viewer.is_admin && <X/>}` renders the literal "0" when is_admin is 0.
// Coerce with `!!(...)`.
describe('UserDisplay viewer-flag truthy handling', () => {
  const numericViewerProps = {
    ...baseProps,
    data: {
      ...baseProps.data,
      // Match what the Perl serializer actually sends: ints, not booleans.
      viewer: { is_editor: 0, is_chanop: 0, is_admin: 0, is_guest: 0 },
    },
  }

  it('does not render a literal "0" in the icon row when viewer has no roles', () => {
    const { container } = render(<UserDisplay {...numericViewerProps} />)
    const iconRow = container.querySelector('.user-display__icon-row')
    // The bug: `{(is_editor || is_chanop || is_admin) && <button/>}` returned
    // 0 (number) and React rendered it as the text node "0" next to the star.
    if (iconRow) {
      // Allow whitespace-only; reject any literal "0" text content.
      expect(iconRow.textContent.replace(/\s+/g, '')).not.toBe('0')
      // Stronger: no direct-child text node should be "0".
      const stray = [...iconRow.childNodes].some(
        (n) => n.nodeType === Node.TEXT_NODE && n.textContent.trim() === '0'
      )
      expect(stray).toBe(false)
    }
  })

  it('does not render a literal "0" in the body when viewer is not an editor and user is locked', () => {
    const lockedUserProps = {
      ...numericViewerProps,
      data: {
        ...numericViewerProps.data,
        user: {
          ...numericViewerProps.data.user,
          acctlock: { node_id: 999, title: 'someadmin' },
        },
      },
    }
    const { container } = render(<UserDisplay {...lockedUserProps} />)
    // Same pattern: `{user.acctlock && viewer.is_editor && <p/>}` rendered "0".
    // The acctlock paragraph correctly stays hidden for non-editors AND no
    // stray "0" gets injected.
    expect(screen.queryByText(/Account locked/)).not.toBeInTheDocument()
    const allText = container.textContent
    // Crude but effective: no isolated "0" appearing between elements
    expect(allText).not.toMatch(/(^|[>\s])0([<\s]|$)/)
  })
})
