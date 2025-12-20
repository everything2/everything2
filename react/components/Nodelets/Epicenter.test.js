import React from 'react'
import { render, screen } from '@testing-library/react'
import Epicenter from './Epicenter'

// Mock child components
jest.mock('../LinkNode', () => {
  return function MockLinkNode({ title, display, type, id, params }) {
    return <span data-testid="link-node">{display || title}</span>
  }
})

jest.mock('../NodeletContainer', () => {
  return function MockNodeletContainer({ title, children, showNodelet, nodeletIsOpen }) {
    return (
      <div data-testid="nodelet-container" data-title={title} data-open={nodeletIsOpen}>
        {children}
      </div>
    )
  }
})

jest.mock('../Borgcheck', () => {
  return function MockBorgcheck({ borged, numborged, currentTime }) {
    return <div data-testid="borgcheck">Borgcheck: {borged}</div>
  }
})

jest.mock('../ExperienceGain', () => {
  return function MockExperienceGain({ amount }) {
    return <span data-testid="experience-gain">You gained {amount} experience points!</span>
  }
})

jest.mock('../GPGain', () => {
  return function MockGPGain({ amount }) {
    return <span data-testid="gp-gain">Yay! You gained {amount} GP!</span>
  }
})

jest.mock('../ServerTime', () => {
  return function MockServerTime({ timeString, showLocalTime, localTimeString }) {
    return (
      <span data-testid="server-time">
        Server time: {timeString}
        {showLocalTime && localTimeString && ` | Your time: ${localTimeString}`}
      </span>
    )
  }
})

describe('Epicenter Component', () => {
  const mockShowNodelet = jest.fn()

  const defaultProps = {
    user: {
      guest: false,
      title: 'testuser',
      node_id: 123,
      gp: 50,
      experience: 1000,
      level: 3,
      gpOptOut: false,
      votesleft: 5,
      coolsleft: 2
    },
    localTimeUse: false,
    userSettingsId: 456,
    helpPage: 'Everything2 Help',
    borgcheck: null,
    experienceGain: 10,
    gpGain: 5,
    randomNodeUrl: '/index.pl?op=randomnode&garbage=12345',
    serverTime: '2025-11-20 12:00:00',
    localTime: null,
    showNodelet: mockShowNodelet,
    nodeletIsOpen: true
  }

  beforeEach(() => {
    mockShowNodelet.mockClear()
  })

  describe('rendering', () => {
    it('renders Epicenter nodelet container', () => {
      render(<Epicenter {...defaultProps} />)

      const container = screen.getByTestId('nodelet-container')
      expect(container).toBeInTheDocument()
      expect(container).toHaveAttribute('data-title', 'Epicenter')
    })

    it('renders navigation links for logged-in users', () => {
      render(<Epicenter {...defaultProps} />)

      expect(screen.getByText('Log Out')).toBeInTheDocument()
      expect(screen.getByText('Drafts')).toBeInTheDocument()
      expect(screen.getByText('Voting/XP System')).toBeInTheDocument()
      expect(screen.getByText('Help')).toBeInTheDocument()
    })

    it('renders votes and cools display', () => {
      render(<Epicenter {...defaultProps} />)

      expect(screen.getByText('5')).toBeInTheDocument()
      expect(screen.getByText(/vote/)).toBeInTheDocument()
      expect(screen.getByText('2')).toBeInTheDocument()
      expect(screen.getByText(/C!/)).toBeInTheDocument()
    })

    it('renders experience display', () => {
      render(<Epicenter {...defaultProps} />)

      expect(screen.getByTestId('experience-gain')).toBeInTheDocument()
      expect(screen.getByText('You gained 10 experience points!')).toBeInTheDocument()
    })

    it('renders GP display when not opted out', () => {
      render(<Epicenter {...defaultProps} />)

      expect(screen.getByTestId('gp-gain')).toBeInTheDocument()
      expect(screen.getByText('Yay! You gained 5 GP!')).toBeInTheDocument()
    })

    it('renders server time display', () => {
      const { container } = render(<Epicenter {...defaultProps} />)

      const timeElement = container.querySelector('#servertime')
      expect(timeElement).toBeInTheDocument()
    })
  })

  describe('guest user', () => {
    it('renders only borgcheck for guest users', () => {
      const guestProps = {
        ...defaultProps,
        user: { ...defaultProps.user, guest: true },
        borgcheck: '<p>You have been borged!</p>'
      }

      render(<Epicenter {...guestProps} />)

      expect(screen.queryByText('Log Out')).not.toBeInTheDocument()
      expect(screen.queryByText('Drafts')).not.toBeInTheDocument()
    })

    it('renders container even for guests', () => {
      const guestProps = {
        ...defaultProps,
        user: { ...defaultProps.user, guest: true }
      }

      render(<Epicenter {...guestProps} />)

      const container = screen.getByTestId('nodelet-container')
      expect(container).toBeInTheDocument()
    })
  })

  describe('votes and cools', () => {
    it('shows singular form for 1 vote', () => {
      const props = { ...defaultProps, user: { ...defaultProps.user, votesleft: 1, coolsleft: 0 } }
      const { container } = render(<Epicenter {...props} />)

      expect(container.querySelector('#votesleft').textContent).toBe('1')
      expect(screen.getByText(/vote/)).toBeInTheDocument()
      expect(container.textContent).not.toContain('votes')
    })

    it('shows plural form for multiple votes', () => {
      const props = { ...defaultProps, user: { ...defaultProps.user, votesleft: 5, coolsleft: 0 } }
      const { container } = render(<Epicenter {...props} />)

      expect(container.querySelector('#votesleft').textContent).toBe('5')
      expect(screen.getByText(/votes/)).toBeInTheDocument()
    })

    it('shows singular form for 1 cool', () => {
      const props = { ...defaultProps, user: { ...defaultProps.user, votesleft: 0, coolsleft: 1 } }
      const { container } = render(<Epicenter {...props} />)

      expect(container.querySelector('#chingsleft').textContent).toBe('1')
      expect(screen.getByText(/C!/)).toBeInTheDocument()
      expect(container.textContent).not.toContain('C!s')
    })

    it('shows plural form for multiple cools', () => {
      const props = { ...defaultProps, user: { ...defaultProps.user, votesleft: 0, coolsleft: 3 } }
      const { container } = render(<Epicenter {...props} />)

      expect(container.querySelector('#chingsleft').textContent).toBe('3')
      expect(screen.getByText(/C!s/)).toBeInTheDocument()
    })

    it('shows both votes and cools when present', () => {
      const props = { ...defaultProps, user: { ...defaultProps.user, votesleft: 5, coolsleft: 2 } }
      const { container } = render(<Epicenter {...props} />)

      expect(container.querySelector('#chingsleft').textContent).toBe('2')
      expect(container.querySelector('#votesleft').textContent).toBe('5')
      expect(screen.getByText(/C!s/)).toBeInTheDocument()
      expect(screen.getByText(/votes/)).toBeInTheDocument()
    })

    it('hides votes/cools section when both are zero', () => {
      const props = { ...defaultProps, user: { ...defaultProps.user, votesleft: 0, coolsleft: 0 } }
      const { container } = render(<Epicenter {...props} />)

      expect(container.querySelector('#voteschingsleft')).not.toBeInTheDocument()
    })
  })

  describe('GP opt-out', () => {
    it('does not render GP display when opted out', () => {
      const props = { ...defaultProps, user: { ...defaultProps.user, gpOptOut: true }, gpGain: 5 }
      render(<Epicenter {...props} />)

      expect(screen.queryByTestId('gp-gain')).not.toBeInTheDocument()
    })

    it('renders GP display when not opted out', () => {
      const props = { ...defaultProps, user: { ...defaultProps.user, gpOptOut: false }, gpGain: 5 }
      render(<Epicenter {...props} />)

      expect(screen.getByTestId('gp-gain')).toBeInTheDocument()
      expect(screen.getByText('Yay! You gained 5 GP!')).toBeInTheDocument()
    })
  })

  describe('help page selection', () => {
    it('uses correct help page for established users', () => {
      const props = { ...defaultProps, helpPage: 'Everything2 Help' }
      render(<Epicenter {...props} />)

      // LinkNode is mocked, but the help page title is passed to it
      expect(screen.getByText('Help')).toBeInTheDocument()
    })

    it('uses quick start for new users', () => {
      const props = { ...defaultProps, helpPage: 'E2 Quick Start' }
      render(<Epicenter {...props} />)

      expect(screen.getByText('Help')).toBeInTheDocument()
    })
  })

  describe('borgcheck', () => {
    it('renders borgcheck when present', () => {
      const props = {
        ...defaultProps,
        borgcheck: { borged: 1234567890, numborged: 2, currentTime: 1234567900 }
      }
      render(<Epicenter {...props} />)

      expect(screen.getByTestId('borgcheck')).toBeInTheDocument()
      expect(screen.getByText('Borgcheck: 1234567890')).toBeInTheDocument()
    })

    it('renders without borgcheck when null', () => {
      const props = { ...defaultProps, borgcheck: null }
      render(<Epicenter {...props} />)

      expect(screen.queryByTestId('borgcheck')).not.toBeInTheDocument()
    })
  })

  describe('component structure', () => {
    it('wraps content in NodeletContainer', () => {
      render(<Epicenter {...defaultProps} />)

      const container = screen.getByTestId('nodelet-container')
      expect(container).toHaveAttribute('data-title', 'Epicenter')
    })

    it('passes nodeletIsOpen prop correctly', () => {
      const { rerender } = render(<Epicenter {...defaultProps} nodeletIsOpen={true} />)
      let container = screen.getByTestId('nodelet-container')
      expect(container).toHaveAttribute('data-open', 'true')

      rerender(<Epicenter {...defaultProps} nodeletIsOpen={false} />)
      container = screen.getByTestId('nodelet-container')
      expect(container).toHaveAttribute('data-open', 'false')
    })
  })

  describe('HTML content rendering', () => {
    it('renders random node link', () => {
      const props = {
        ...defaultProps,
        randomNodeUrl: '/index.pl?op=randomnode&garbage=12345'
      }
      const { container } = render(<Epicenter {...props} />)

      const link = container.querySelector('a[href="/index.pl?op=randomnode&garbage=12345"]')
      expect(link).toBeInTheDocument()
      expect(link.textContent).toBe('Random Node')
    })

    it('renders server time', () => {
      const props = {
        ...defaultProps,
        serverTime: 'Monday, November 20, 2025 at 12:00:00'
      }
      render(<Epicenter {...props} />)

      expect(screen.getByTestId('server-time')).toBeInTheDocument()
      expect(screen.getByText(/Server time: Monday, November 20, 2025/)).toBeInTheDocument()
    })
  })

  describe('integration with other components', () => {
    it('renders multiple LinkNode components', () => {
      render(<Epicenter {...defaultProps} />)

      const linkNodes = screen.getAllByTestId('link-node')
      // Should have links for: Log Out, User Settings, User Profile, Profile Edit,
      // Drafts, Voting/XP System, Help
      expect(linkNodes.length).toBeGreaterThanOrEqual(7)
    })
  })
})
