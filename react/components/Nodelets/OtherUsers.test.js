import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import OtherUsers from './OtherUsers'

// Stub fetch — tests that exercise the click/change paths replace it per case.
global.fetch = jest.fn()

// Mock the polling hook. Use real React state so the component can drive
// setOtherUsersData updates through the hook (needed for the cloak-flag
// regression test below — without this, the cloak response can't sync back
// into the polled state and the user list stays stale).
jest.mock('../../hooks/useOtherUsersPolling', () => {
  const { useState } = require('react')
  return {
    useOtherUsersPolling: (pollIntervalMs, initialData) => {
      const [otherUsersData, setOtherUsersData] = useState(initialData ?? null)
      return {
        otherUsersData,
        loading: false,
        error: null,
        refresh: jest.fn(),
        setOtherUsersData
      }
    }
  }
})

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

  describe('React 19 regression guards', () => {
    // These tests pin behavior that's easy to silently regress under a
    // React 19 upgrade (StrictMode double-effects, controlled-input
    // batching changes). If one of these breaks, the nodelet UX broke
    // before any user can tell us.

    beforeEach(() => {
      jest.clearAllMocks()
    })

    test('no [Go] button — room change fires on dropdown change alone', async () => {
      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          success: 1,
          room_id: 456,
          room_title: 'Other Room',
          otherUsersData: { ...mockData, currentRoomId: 456 }
        })
      })

      render(<OtherUsers otherUsersData={mockData} />)

      // The old UI had a [Go] button next to the dropdown. The whole point
      // of the cleanup is that it's gone — guard against it sneaking back.
      expect(screen.queryByRole('button', { name: /^Go$/ })).not.toBeInTheDocument()

      // Changing the select must POST change_room with the new id —
      // without any additional click.
      const select = document.getElementById('otherusers-room-select')
      fireEvent.change(select, { target: { value: '456' } })

      await waitFor(() => {
        expect(global.fetch).toHaveBeenCalledWith(
          '/api/chatroom/change_room',
          expect.objectContaining({
            method: 'POST',
            body: JSON.stringify({ room_id: 456 })
          })
        )
      })
    })

    test('cloak checkbox flips optimistically — checked state lands before the API resolves', async () => {
      // Hand-controlled promise so we can inspect the DOM mid-flight.
      let resolveSetCloaked
      global.fetch.mockReturnValueOnce(new Promise((resolve) => {
        resolveSetCloaked = () => resolve({
          ok: true,
          json: async () => ({ success: 1, cloaked: 1, otherUsersData: { ...mockData, isCloaked: 1 } })
        })
      }))

      render(<OtherUsers otherUsersData={{ ...mockData, canCloak: true, isCloaked: false }} />)

      const cloakBox = document.getElementById('otherusers-cloaked')
      expect(cloakBox.checked).toBe(false)

      fireEvent.click(cloakBox)

      // The optimistic flip is the whole point — the checkbox must be
      // checked *before* we resolve the fetch. Previous (pre-#3990 follow-up)
      // behavior waited for the API and looked unresponsive for ~100-300ms.
      expect(cloakBox.checked).toBe(true)

      // Resolve the API; state should remain checked.
      resolveSetCloaked()
      await waitFor(() => {
        expect(cloakBox.checked).toBe(true)
      })
    })

    test('clicking cloak updates the user list with the invisible flag without waiting for a poll', async () => {
      // Server reports the invisible flag on the current user only when the
      // viewer is an editor/chanop/infravision (see buildOtherUsersData).
      // We simulate that response and assert the list re-renders with the
      // cloak icon immediately — not after the next 2-minute poll.
      const cloakedData = {
        ...mockData,
        canCloak: true,
        isCloaked: 1,
        rooms: [
          {
            title: '',
            users: [
              { userId: 1, displayName: 'alice', isCurrentUser: true, flags: [{ type: 'invisible' }], action: null },
              { userId: 2, displayName: 'bob', isCurrentUser: false, flags: [], action: null }
            ]
          }
        ]
      }

      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ success: 1, cloaked: 1, otherUsersData: cloakedData })
      })

      const { container } = render(
        <OtherUsers otherUsersData={{ ...mockData, canCloak: true, isCloaked: 0 }} />
      )

      // Pre-click: no invisible flag shown anywhere.
      expect(container.querySelector('.otherusers-invisible')).toBeNull()

      fireEvent.click(document.getElementById('otherusers-cloaked'))

      // The cloak icon appears as soon as the API responds — no extra GET,
      // no polling interval.
      await waitFor(() => {
        expect(container.querySelector('.otherusers-invisible')).not.toBeNull()
      })
    })

    test('cloak checkbox rolls back on API failure', async () => {
      global.fetch.mockResolvedValueOnce({
        ok: false,
        json: async () => ({ error: 'no soup for you' })
      })

      render(<OtherUsers otherUsersData={{ ...mockData, canCloak: true, isCloaked: false }} />)

      const cloakBox = document.getElementById('otherusers-cloaked')
      fireEvent.click(cloakBox)
      expect(cloakBox.checked).toBe(true)   // optimistic flip

      await waitFor(() => {
        expect(cloakBox.checked).toBe(false) // reverted
      })
    })
  })
})
