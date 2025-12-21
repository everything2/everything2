import React from 'react'
import { render, screen } from '@testing-library/react'
import TimeSince from './TimeSince'

// Mock TimeDistance since we're testing TimeSince's conversion logic
jest.mock('./TimeDistance', () => {
  return function MockTimeDistance({ then }) {
    return <span data-testid="time-distance" data-then={then}>mocked time</span>
  }
})

describe('TimeSince', () => {
  it('passes through Unix timestamp directly', () => {
    const unixTime = 1702234567
    render(<TimeSince timestamp={unixTime} />)

    const timeDistance = screen.getByTestId('time-distance')
    expect(timeDistance).toHaveAttribute('data-then', String(unixTime))
  })

  it('converts MySQL datetime string to Unix timestamp', () => {
    // MySQL datetime: "2025-12-10 19:33:59"
    // Should be converted to UTC Unix timestamp
    const mysqlDatetime = '2025-12-10 19:33:59'
    render(<TimeSince timestamp={mysqlDatetime} />)

    const timeDistance = screen.getByTestId('time-distance')
    const expectedUnix = Math.floor(new Date('2025-12-10T19:33:59Z').getTime() / 1000)
    expect(timeDistance).toHaveAttribute('data-then', String(expectedUnix))
  })

  it('handles midnight datetime correctly', () => {
    const mysqlDatetime = '2025-01-01 00:00:00'
    render(<TimeSince timestamp={mysqlDatetime} />)

    const timeDistance = screen.getByTestId('time-distance')
    const expectedUnix = Math.floor(new Date('2025-01-01T00:00:00Z').getTime() / 1000)
    expect(timeDistance).toHaveAttribute('data-then', String(expectedUnix))
  })

  it('handles end of day datetime correctly', () => {
    const mysqlDatetime = '2025-12-31 23:59:59'
    render(<TimeSince timestamp={mysqlDatetime} />)

    const timeDistance = screen.getByTestId('time-distance')
    const expectedUnix = Math.floor(new Date('2025-12-31T23:59:59Z').getTime() / 1000)
    expect(timeDistance).toHaveAttribute('data-then', String(expectedUnix))
  })

  it('renders TimeDistance component', () => {
    render(<TimeSince timestamp={1702234567} />)
    expect(screen.getByText('mocked time')).toBeInTheDocument()
  })
})
