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
