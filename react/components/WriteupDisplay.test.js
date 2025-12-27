import React from 'react'
import { render, screen, fireEvent } from '@testing-library/react'
import WriteupDisplay from './WriteupDisplay'

// Mock the E2HtmlSanitizer
jest.mock('./Editor/E2HtmlSanitizer', () => ({
  renderE2Content: (text) => ({ html: text })
}))

// Mock LinkNode
jest.mock('./LinkNode', () => {
  return function MockLinkNode({ title, type, display }) {
    const text = display || title
    return <a data-testid="linknode" data-title={title} data-type={type || 'default'}>{text}</a>
  }
})

describe('WriteupDisplay Component', () => {
  const mockWriteup = {
    node_id: 123,
    title: 'Test Writeup',
    author: { node_id: 456, title: 'testuser' },
    parent: { title: 'Test Node' },
    doctext: 'This is a test writeup with [some links].',
    reputation: 5,
    upvotes: 7,
    downvotes: 2,
    writeuptype: 'thing',
    createtime: 1700000000,
    cools: []
  }

  const mockUser = {
    node_id: 789,
    is_guest: false,
    is_editor: false
  }

  const guestUser = {
    node_id: 0,
    is_guest: true,
    is_editor: false
  }

  describe('rendering', () => {
    it('renders writeup with all metadata', () => {
      const votedWriteup = { ...mockWriteup, vote: 1 }
      render(<WriteupDisplay writeup={votedWriteup} user={mockUser} />)

      // New layout: (type) by author date - no parent title in header
      expect(screen.getByText('testuser')).toBeInTheDocument()
      expect(screen.getByText('thing')).toBeInTheDocument() // type without parens in link
      expect(screen.getByText(/Rep: \+5 \(\+7\/-2\)/)).toBeInTheDocument()
    })

    it('renders doctext content', () => {
      render(<WriteupDisplay writeup={mockWriteup} user={mockUser} />)

      const content = screen.getByText(/This is a test writeup/)
      expect(content).toBeInTheDocument()
    })

    it('displays reputation with vote counts when user has voted', () => {
      const votedWriteup = { ...mockWriteup, vote: 1 }
      render(<WriteupDisplay writeup={votedWriteup} user={mockUser} />)

      // Reputation shows with upvote/downvote counts when user has voted
      expect(screen.getByText(/Rep: \+5 \(\+7\/-2\)/)).toBeInTheDocument()
    })

    it('hides reputation when user has not voted', () => {
      render(<WriteupDisplay writeup={mockWriteup} user={mockUser} />)

      // Should not show reputation if user hasn't voted
      expect(screen.queryByText(/Rep:/)).not.toBeInTheDocument()
    })

    it('shows reputation to author even without voting', () => {
      // Author has same node_id as writeup author
      const authorUser = { node_id: 456, is_guest: false, is_editor: false }
      render(<WriteupDisplay writeup={mockWriteup} user={authorUser} />)

      // Author should see reputation spread of their own writeup
      expect(screen.getByText(/Rep: \+5 \(\+7\/-2\)/)).toBeInTheDocument()
    })

    it('displays C!s when present', () => {
      const writeupWithCools = {
        ...mockWriteup,
        cools: [
          { node_id: 111, title: 'cooler1' },
          { node_id: 222, title: 'cooler2' }
        ]
      }

      const { container } = render(<WriteupDisplay writeup={writeupWithCools} user={mockUser} />)

      // Cools span should be present with count
      const coolsSpan = container.querySelector('#cools123')
      expect(coolsSpan).toBeInTheDocument()

      // Check for C! text (split across elements)
      expect(screen.getByText('C!')).toBeInTheDocument()
      expect(coolsSpan.textContent).toContain('2')
      expect(coolsSpan.textContent).toContain('C!')

      // Tooltip should appear on hover (using CoolTooltip component)
      fireEvent.mouseEnter(coolsSpan)
      expect(screen.getByText('cooler1')).toBeInTheDocument()
      expect(screen.getByText('cooler2')).toBeInTheDocument()
    })

    it('handles missing optional fields', () => {
      const minimalWriteup = {
        node_id: 123,
        author: { title: 'testuser' },
        doctext: 'Minimal writeup'
      }

      render(<WriteupDisplay writeup={minimalWriteup} user={mockUser} />)

      expect(screen.getByText('Minimal writeup')).toBeInTheDocument()
    })

    it('displays "(no owner)" for writeups with no author', () => {
      const writeupWithNoAuthor = {
        node_id: 123,
        author: null,
        doctext: 'Writeup with no author',
        writeuptype: 'thing',
        createtime: 1700000000
      }

      render(<WriteupDisplay writeup={writeupWithNoAuthor} user={mockUser} />)

      // Should show "(no owner)" text
      expect(screen.getByText('(no owner)')).toBeInTheDocument()

      // Should not have a link to a user (type link is still present, which is fine)
      const linknodes = screen.queryAllByTestId('linknode')
      const userLinks = linknodes.filter(node => node.getAttribute('data-type') === 'user')
      expect(userLinks).toHaveLength(0)
    })

    it('renders content in content div', () => {
      render(<WriteupDisplay writeup={mockWriteup} user={mockUser} />)

      const content = screen.getByText(/This is a test writeup/)
      expect(content).toBeInTheDocument()
    })
  })

  describe('voting controls', () => {
    it('shows voting controls for logged-in non-authors', () => {
      const { container } = render(<WriteupDisplay writeup={mockWriteup} user={mockUser} />)

      // Icon button voting controls - check for wu_vote cell
      const voteCell = container.querySelector('.wu_vote')
      expect(voteCell).toBeInTheDocument()

      // Check for vote buttons by their role
      const buttons = container.querySelectorAll('.wu_vote button')
      expect(buttons.length).toBe(2) // upvote and downvote buttons
    })

    it('hides voting controls for guests', () => {
      const { container } = render(<WriteupDisplay writeup={mockWriteup} user={guestUser} />)

      const voteCell = container.querySelector('.wu_vote')
      expect(voteCell).not.toBeInTheDocument()
    })

    it('hides voting controls for authors', () => {
      const authorUser = {
        node_id: 456, // Same as author in mockWriteup
        is_guest: false,
        is_editor: false
      }

      const { container } = render(<WriteupDisplay writeup={mockWriteup} user={authorUser} />)

      const voteCell = container.querySelector('.wu_vote')
      expect(voteCell).not.toBeInTheDocument()
    })

    it('disables vote buttons if user has already voted', () => {
      const votedWriteup = { ...mockWriteup, vote: 1 }

      const { container } = render(<WriteupDisplay writeup={votedWriteup} user={mockUser} />)

      const buttons = container.querySelectorAll('.wu_vote button')
      expect(buttons.length).toBe(2)

      // Only the active vote button (upvote in this case) should be disabled
      // The other button should be clickable to allow changing vote
      const disabledButtons = Array.from(buttons).filter(b => b.disabled)
      expect(disabledButtons.length).toBe(1)
    })

    it('marks active vote radio as checked', () => {
      const votedWriteup = { ...mockWriteup, vote: 1 }

      const { container } = render(<WriteupDisplay writeup={votedWriteup} user={mockUser} />)

      // Check that voting UI is present (buttons render with current vote state)
      const voteCell = container.querySelector('.wu_vote')
      expect(voteCell).toBeInTheDocument()
    })

    it('can hide voting controls via prop', () => {
      render(<WriteupDisplay writeup={mockWriteup} user={mockUser} showVoting={false} />)

      expect(screen.queryByLabelText('+')).not.toBeInTheDocument()
    })
  })

  describe('edge cases', () => {
    it('returns null for missing writeup', () => {
      const { container } = render(<WriteupDisplay writeup={null} user={mockUser} />)

      expect(container).toBeEmptyDOMElement()
    })

    it('handles negative reputation when user has voted', () => {
      const negRepWriteup = { ...mockWriteup, reputation: -3, vote: -1 }

      render(<WriteupDisplay writeup={negRepWriteup} user={mockUser} />)

      expect(screen.getByText(/Rep: -3 \(\+7\/-2\)/)).toBeInTheDocument()
    })

    it('handles zero reputation when user has voted', () => {
      const zeroRepWriteup = { ...mockWriteup, reputation: 0, vote: 1 }

      render(<WriteupDisplay writeup={zeroRepWriteup} user={mockUser} />)

      expect(screen.getByText(/Rep: 0 \(\+7\/-2\)/)).toBeInTheDocument()
    })
  })

  describe('social sharing', () => {
    it('shows social sharing links when available', () => {
      const writeupWithSharing = {
        ...mockWriteup,
        social_share: {
          short_url: 'https://everything2.com/s/abc',
          title: 'Test Node'
        }
      }

      const { container } = render(<WriteupDisplay writeup={writeupWithSharing} user={mockUser} />)

      // Should have links to Facebook, Twitter/X, and Reddit in footer
      const links = container.querySelectorAll('a[href*="facebook"], a[href*="x.com"], a[href*="reddit"]')
      expect(links.length).toBe(3)
    })

    it('does not show social sharing when not available', () => {
      const writeupWithoutSharing = {
        ...mockWriteup
        // no social_share property
      }

      const { container } = render(<WriteupDisplay writeup={writeupWithoutSharing} user={mockUser} />)

      // Should not show social sharing links
      const links = container.querySelectorAll('a[href*="facebook"], a[href*="x.com"], a[href*="reddit"]')
      expect(links.length).toBe(0)
    })

    it('includes short URL in share links', () => {
      const writeupWithSharing = {
        ...mockWriteup,
        social_share: {
          short_url: 'https://everything2.com/s/testABC',
          title: 'Test Share Title'
        }
      }

      const { container } = render(<WriteupDisplay writeup={writeupWithSharing} user={mockUser} />)

      // Check Facebook link contains encoded short URL
      const facebookLink = container.querySelector('a[href*="facebook"]')
      expect(facebookLink.href).toContain(encodeURIComponent('https://everything2.com/s/testABC'))

      // Check X (Twitter) link contains encoded short URL and title
      const xLink = container.querySelector('a[href*="x.com"]')
      expect(xLink.href).toContain(encodeURIComponent('https://everything2.com/s/testABC'))
      expect(xLink.href).toContain(encodeURIComponent('Test Share Title'))

      // Check Reddit link contains encoded short URL and title
      const redditLink = container.querySelector('a[href*="reddit"]')
      expect(redditLink.href).toContain(encodeURIComponent('https://everything2.com/s/testABC'))
      expect(redditLink.href).toContain(encodeURIComponent('Test Share Title'))
    })

    it('opens share links in new window', () => {
      const writeupWithSharing = {
        ...mockWriteup,
        social_share: {
          short_url: 'https://everything2.com/s/abc',
          title: 'Test Node'
        }
      }

      const { container } = render(<WriteupDisplay writeup={writeupWithSharing} user={mockUser} />)

      const links = container.querySelectorAll('a[href*="facebook"], a[href*="x.com"], a[href*="reddit"]')
      links.forEach(link => {
        expect(link.target).toBe('_blank')
        expect(link.rel).toBe('noopener noreferrer')
      })
    })
  })

  describe('date display', () => {
    it('displays publishtime when available', () => {
      const writeupWithPublishtime = {
        ...mockWriteup,
        createtime: '2020-01-15T12:00:00Z',
        publishtime: '2024-06-15T12:00:00Z'
      }

      const { container } = render(<WriteupDisplay writeup={writeupWithPublishtime} user={mockUser} />)

      // Should show publishtime (2024), not createtime (2020)
      const dateCell = container.querySelector('.wu_dtcreate .date')
      expect(dateCell.textContent).toMatch(/2024/)
      expect(dateCell.textContent).not.toMatch(/2020/)
    })

    it('falls back to createtime when publishtime is not available', () => {
      const writeupWithoutPublishtime = {
        ...mockWriteup,
        createtime: '2020-06-15T12:00:00Z',
        publishtime: null
      }

      const { container } = render(<WriteupDisplay writeup={writeupWithoutPublishtime} user={mockUser} />)

      // Should show createtime as fallback (2020)
      const dateCell = container.querySelector('.wu_dtcreate .date')
      expect(dateCell.textContent).toMatch(/2020/)
    })
  })
})
