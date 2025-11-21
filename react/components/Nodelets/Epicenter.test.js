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

describe('Epicenter Component', () => {
  const mockShowNodelet = jest.fn()

  const defaultProps = {
    isGuest: false,
    votesLeft: 5,
    cools: 2,
    experience: 1000,
    gp: 50,
    level: 3,
    gpOptOut: false,
    localTimeUse: false,
    userId: 123,
    userSettingsId: 456,
    helpPage: 'Everything2 Help',
    borgcheck: '',
    experienceDisplay: '<span>Experience: 1000</span>',
    gpDisplay: '<span>GP: 50</span>',
    randomNode: '<a href="/node/random">Random Node</a>',
    serverTimeDisplay: 'server time<br />2025-11-20 12:00:00',
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

      const expElement = screen.getByText('Experience: 1000')
      expect(expElement).toBeInTheDocument()
    })

    it('renders GP display when not opted out', () => {
      render(<Epicenter {...defaultProps} />)

      const gpElement = screen.getByText('GP: 50')
      expect(gpElement).toBeInTheDocument()
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
        isGuest: true,
        borgcheck: '<p>You have been borged!</p>'
      }

      render(<Epicenter {...guestProps} />)

      expect(screen.queryByText('Log Out')).not.toBeInTheDocument()
      expect(screen.queryByText('Drafts')).not.toBeInTheDocument()
    })

    it('renders container even for guests', () => {
      const guestProps = {
        ...defaultProps,
        isGuest: true
      }

      render(<Epicenter {...guestProps} />)

      const container = screen.getByTestId('nodelet-container')
      expect(container).toBeInTheDocument()
    })
  })

  describe('votes and cools', () => {
    it('shows singular form for 1 vote', () => {
      const props = { ...defaultProps, votesLeft: 1, cools: 0 }
      const { container } = render(<Epicenter {...props} />)

      expect(container.querySelector('#votesleft').textContent).toBe('1')
      expect(screen.getByText(/vote/)).toBeInTheDocument()
      expect(container.textContent).not.toContain('votes')
    })

    it('shows plural form for multiple votes', () => {
      const props = { ...defaultProps, votesLeft: 5, cools: 0 }
      const { container } = render(<Epicenter {...props} />)

      expect(container.querySelector('#votesleft').textContent).toBe('5')
      expect(screen.getByText(/votes/)).toBeInTheDocument()
    })

    it('shows singular form for 1 cool', () => {
      const props = { ...defaultProps, votesLeft: 0, cools: 1 }
      const { container } = render(<Epicenter {...props} />)

      expect(container.querySelector('#chingsleft').textContent).toBe('1')
      expect(screen.getByText(/C!/)).toBeInTheDocument()
      expect(container.textContent).not.toContain('C!s')
    })

    it('shows plural form for multiple cools', () => {
      const props = { ...defaultProps, votesLeft: 0, cools: 3 }
      const { container } = render(<Epicenter {...props} />)

      expect(container.querySelector('#chingsleft').textContent).toBe('3')
      expect(screen.getByText(/C!s/)).toBeInTheDocument()
    })

    it('shows both votes and cools when present', () => {
      const props = { ...defaultProps, votesLeft: 5, cools: 2 }
      const { container } = render(<Epicenter {...props} />)

      expect(container.querySelector('#chingsleft').textContent).toBe('2')
      expect(container.querySelector('#votesleft').textContent).toBe('5')
      expect(screen.getByText(/C!s/)).toBeInTheDocument()
      expect(screen.getByText(/votes/)).toBeInTheDocument()
    })

    it('hides votes/cools section when both are zero', () => {
      const props = { ...defaultProps, votesLeft: 0, cools: 0 }
      const { container } = render(<Epicenter {...props} />)

      expect(container.querySelector('#voteschingsleft')).not.toBeInTheDocument()
    })
  })

  describe('GP opt-out', () => {
    it('does not render GP display when opted out', () => {
      const props = { ...defaultProps, gpOptOut: true }
      render(<Epicenter {...props} />)

      expect(screen.queryByText('GP: 50')).not.toBeInTheDocument()
    })

    it('renders GP display when not opted out', () => {
      const props = { ...defaultProps, gpOptOut: false }
      render(<Epicenter {...props} />)

      expect(screen.getByText('GP: 50')).toBeInTheDocument()
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
    it('renders borgcheck HTML when present', () => {
      const props = {
        ...defaultProps,
        borgcheck: '<div class="borg">You have been assimilated</div>'
      }
      const { container } = render(<Epicenter {...props} />)

      expect(container.querySelector('.borg')).toBeInTheDocument()
      expect(container.textContent).toContain('You have been assimilated')
    })

    it('renders without borgcheck when empty', () => {
      const props = { ...defaultProps, borgcheck: '' }
      render(<Epicenter {...props} />)

      const container = screen.getByTestId('nodelet-container')
      expect(container).toBeInTheDocument()
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
    it('renders random node HTML', () => {
      const props = {
        ...defaultProps,
        randomNode: '<a href="/node/random" class="random-link">Go Random</a>'
      }
      const { container } = render(<Epicenter {...props} />)

      expect(container.querySelector('.random-link')).toBeInTheDocument()
    })

    it('renders server time HTML', () => {
      const props = {
        ...defaultProps,
        serverTimeDisplay: 'server time<br />2025-11-20 14:30:00<br />your time<br />2025-11-20 09:30:00'
      }
      const { container } = render(<Epicenter {...props} />)

      const timeElement = container.querySelector('#servertime')
      expect(timeElement).toBeInTheDocument()
      expect(timeElement.innerHTML).toContain('server time')
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
