import React from 'react'
import { render, screen } from '@testing-library/react'
import OtherUsers from './OtherUsers'

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

describe('OtherUsers', () => {
  const mockData = {
    userCount: 3,
    currentRoom: '<a href="/node/123">Main Room</a>',
    currentRoomId: 123,
    availableRooms: [
      { room_id: 0, title: 'outside' },
      { room_id: 123, title: 'Main Room' },
      { room_id: 456, title: 'Other Room' }
    ],
    canCloak: false,
    isCloaked: false,
    suspension: null,
    canCreateRoom: false,
    createRoomSuspended: false,
    rooms: [
      {
        title: '',
        users: [
          { userId: 1, displayName: 'alice', isCurrentUser: true, flags: ['@'], action: null },
          { userId: 2, displayName: 'bob', isCurrentUser: false, flags: [], action: null },
          { userId: 3, displayName: 'charlie', isCurrentUser: false, flags: ['$'], action: null }
        ]
      }
    ]
  }

  test('shows friendly message when otherUsersData is undefined', () => {
    render(<OtherUsers otherUsersData={undefined} />)

    expect(screen.getByText('No chat data available')).toBeInTheDocument()
  })

  test('shows friendly message when otherUsersData is null', () => {
    render(<OtherUsers otherUsersData={null} />)

    expect(screen.getByText('No chat data available')).toBeInTheDocument()
  })

  test('shows "no noders" message when userCount is 0', () => {
    const emptyData = {
      ...mockData,
      userCount: 0,
      rooms: [],
      availableRooms: [{ room_id: 0, title: 'outside' }]
    }
    render(<OtherUsers otherUsersData={emptyData} />)

    expect(screen.getByText('There are no noders in this room.')).toBeInTheDocument()
  })

  test('renders user count', () => {
    const { container } = render(<OtherUsers otherUsersData={mockData} />)

    expect(container.textContent).toContain('Your fellow users (3)')
  })

  test('renders room selector', () => {
    const { container } = render(<OtherUsers otherUsersData={mockData} />)

    expect(container.innerHTML).toContain('Main Room')
    expect(container.innerHTML).toContain('outside')
  })

  test('renders current room', () => {
    const { container } = render(<OtherUsers otherUsersData={mockData} />)

    expect(container.innerHTML).toContain('Main Room')
  })

  test('renders user list', () => {
    const { container } = render(<OtherUsers otherUsersData={mockData} />)

    // Component renders user display names, check for their presence
    expect(container.textContent).toContain('alice')
    expect(container.textContent).toContain('bob')
    expect(container.textContent).toContain('charlie')
  })

  test('renders multiple rooms', () => {
    const multiRoomData = {
      ...mockData,
      userCount: 5,
      availableRooms: [
        { room_id: 0, title: 'outside' },
        { room_id: 123, title: 'Main Room' },
        { room_id: 789, title: 'Outside' }
      ],
      rooms: [
        {
          title: 'Main Room',
          users: ['<a href="/user/alice">alice</a>', '<a href="/user/bob">bob</a>']
        },
        {
          title: 'Outside',
          users: ['<a href="/user/charlie">charlie</a>']
        }
      ]
    }

    const { container } = render(<OtherUsers otherUsersData={multiRoomData} />)

    expect(container.textContent).toContain('Main Room:')
    expect(container.textContent).toContain('Outside:')
  })
})
