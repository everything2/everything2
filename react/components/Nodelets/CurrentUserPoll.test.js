import React from 'react'
import { render, screen, fireEvent } from '@testing-library/react'
import CurrentUserPoll from './CurrentUserPoll'

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
  return function LinkNode({ id, title, type, display }) {
    const displayText = display || title || `Node ${id}`
    return <a data-testid="link-node">{displayText}</a>
  }
})

jest.mock('../ParseLinks', () => {
  return function ParseLinks({ text }) {
    return <span>{text}</span>
  }
})

describe('CurrentUserPoll', () => {
  const mockPoll = {
    node_id: 123,
    title: 'Test Poll',
    poll_author: 456,
    author_name: 'PollAuthor',
    question: 'What is your favorite color?',
    options: ['Red', 'Blue', 'Green'],
    poll_status: 'current',
    e2poll_results: [10, 20, 5],
    totalvotes: 35,
    userVote: -1
  }

  const mockUser = {
    node_id: 789,
    title: 'testuser',
    admin: false
  }

  const mockAdminUser = {
    node_id: 1,
    title: 'root',
    admin: true
  }

  test('shows "No current poll" when poll is undefined', () => {
    render(<CurrentUserPoll currentPoll={undefined} user={mockUser} />)

    expect(screen.getByText('No current poll.')).toBeInTheDocument()
  })

  test('shows "No current poll" when poll is null', () => {
    render(<CurrentUserPoll currentPoll={null} user={mockUser} />)

    expect(screen.getByText('No current poll.')).toBeInTheDocument()
  })

  test('renders poll with voting form when user has not voted', () => {
    render(<CurrentUserPoll currentPoll={mockPoll} user={mockUser} />)

    expect(screen.getByText('Test Poll')).toBeInTheDocument()
    expect(screen.getByText('PollAuthor')).toBeInTheDocument()
    expect(screen.getByText('What is your favorite color?')).toBeInTheDocument()
    expect(screen.getByText('Red')).toBeInTheDocument()
    expect(screen.getByText('Blue')).toBeInTheDocument()
    expect(screen.getByText('Green')).toBeInTheDocument()
    expect(screen.getByDisplayValue('vote')).toBeInTheDocument()
  })

  test('renders results table when user has voted', () => {
    const votedPoll = { ...mockPoll, userVote: 1 }
    render(<CurrentUserPoll currentPoll={votedPoll} user={mockUser} />)

    expect(screen.getByText('10')).toBeInTheDocument()
    expect(screen.getByText('20')).toBeInTheDocument()
    expect(screen.getByText('5')).toBeInTheDocument()
    expect(screen.getByText('Total')).toBeInTheDocument()
    expect(screen.getByText('35')).toBeInTheDocument()
  })

  test('renders results table when poll is closed', () => {
    const closedPoll = { ...mockPoll, poll_status: 'closed', userVote: -1 }
    render(<CurrentUserPoll currentPoll={closedPoll} user={mockUser} />)

    expect(screen.getByText('Total')).toBeInTheDocument()
    expect(screen.queryByDisplayValue('vote')).not.toBeInTheDocument()
  })

  test('renders disabled voting form when poll is new', () => {
    const newPoll = { ...mockPoll, poll_status: 'new' }
    render(<CurrentUserPoll currentPoll={newPoll} user={mockUser} />)

    const radios = screen.getAllByRole('radio')
    radios.forEach((radio) => {
      expect(radio).toBeDisabled()
    })
    expect(screen.queryByDisplayValue('vote')).not.toBeInTheDocument()
  })

  test('allows selecting a vote option', () => {
    render(<CurrentUserPoll currentPoll={mockPoll} user={mockUser} />)

    const radios = screen.getAllByRole('radio')
    fireEvent.click(radios[1])

    expect(radios[1]).toBeChecked()
  })

  test('displays poll status when not current', () => {
    const closedPoll = { ...mockPoll, poll_status: 'closed' }
    const { container } = render(<CurrentUserPoll currentPoll={closedPoll} user={mockUser} />)

    expect(container.textContent).toContain('(closed)')
  })

  test('does not display poll status when current', () => {
    const { container } = render(<CurrentUserPoll currentPoll={mockPoll} user={mockUser} />)

    expect(container.textContent).not.toContain('(current)')
  })

  test('renders footer links', () => {
    render(<CurrentUserPoll currentPoll={mockPoll} user={mockUser} />)

    expect(screen.getByText('Past polls')).toBeInTheDocument()
    expect(screen.getByText('Future polls')).toBeInTheDocument()
    expect(screen.getByText('New poll')).toBeInTheDocument()
    expect(screen.getByText('About polls')).toBeInTheDocument()
  })

  test('calculates percentages correctly', () => {
    const votedPoll = { ...mockPoll, userVote: 1 }
    const { container } = render(<CurrentUserPoll currentPoll={votedPoll} user={mockUser} />)

    // 10/35 = 28.57%
    expect(container.textContent).toContain('28.57%')
    // 20/35 = 57.14%
    expect(container.textContent).toContain('57.14%')
    // 5/35 = 14.29%
    expect(container.textContent).toContain('14.29%')
  })

  test('handles zero votes correctly', () => {
    const noPoll = {
      ...mockPoll,
      e2poll_results: [0, 0, 0],
      totalvotes: 0,
      userVote: -1,
      poll_status: 'closed'
    }
    const { container } = render(<CurrentUserPoll currentPoll={noPoll} user={mockUser} />)

    expect(container.textContent).toContain('0.00%')
  })

  test('shows delete button for admin users who have voted', () => {
    const votedPoll = { ...mockPoll, userVote: 1 }
    render(<CurrentUserPoll currentPoll={votedPoll} user={mockAdminUser} />)

    expect(screen.getByText('Delete my vote (admin)')).toBeInTheDocument()
  })

  test('does not show delete button for non-admin users', () => {
    const votedPoll = { ...mockPoll, userVote: 1 }
    render(<CurrentUserPoll currentPoll={votedPoll} user={mockUser} />)

    expect(screen.queryByText('Delete my vote (admin)')).not.toBeInTheDocument()
  })

  test('does not show delete button for admin users who have not voted', () => {
    render(<CurrentUserPoll currentPoll={mockPoll} user={mockAdminUser} />)

    expect(screen.queryByText('Delete my vote (admin)')).not.toBeInTheDocument()
  })

  test('does not show delete button when user is undefined', () => {
    const votedPoll = { ...mockPoll, userVote: 1 }
    render(<CurrentUserPoll currentPoll={votedPoll} user={undefined} />)

    expect(screen.queryByText('Delete my vote (admin)')).not.toBeInTheDocument()
  })
})
