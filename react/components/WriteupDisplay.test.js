import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
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

// Mock MessageModal to capture props. We expose `onSend` and the
// showFeedbackOption prop so tests can simulate the editor submitting the
// modal with a chosen feedback-checkbox state and observe what WriteupDisplay
// does in response (specifically: whether it POSTs a nodenote alongside the
// /api/messages/create call).
jest.mock('./MessageModal', () => {
  return function MockMessageModal({ isOpen, initialMessage, onSend, showFeedbackOption }) {
    if (!isOpen) return null
    return (
      <div
        data-testid="message-modal"
        data-initial-message={initialMessage || ''}
        data-show-feedback={showFeedbackOption ? '1' : '0'}
      >
        Message Modal
        <button
          type="button"
          data-testid="message-modal__send-feedback"
          onClick={() => onSend && onSend('author', 'looks good', { isFeedback: true })}
        >
          send feedback
        </button>
        <button
          type="button"
          data-testid="message-modal__send-plain"
          onClick={() => onSend && onSend('author', 'just chatting', { isFeedback: false })}
        >
          send plain
        </button>
      </div>
    )
  }
})

// Mock ConfirmActionModal so we can observe vote/cool safety modals
// without rendering react-modal's actual DOM (jsdom + react-modal trip
// each other up over document.body portal handling).
jest.mock('./ConfirmActionModal', () => {
  return function MockConfirmActionModal({ isOpen, title }) {
    if (!isOpen) return null
    return <div data-testid="confirm-action-modal">{title}</div>
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

    it('offers the Rep Graph icon link beside the revealed reputation (restored entry point)', () => {
      // The reputation graph has no other UI entry point; it lives inline with the Rep count,
      // shown to exactly the audience allowed to view the graph (author or voter).
      const votedWriteup = { ...mockWriteup, vote: 1 }
      render(<WriteupDisplay writeup={votedWriteup} user={mockUser} />)

      const link = screen.getByRole('link', { name: /reputation graph/i })
      expect(link).toBeInTheDocument()
      // deep-links to the graph superdoc carrying this writeup's node_id
      expect(link).toHaveAttribute('href', '/title/Reputation+Graph?id=123')
      // renders as an icon, not the old text label
      expect(link.querySelector('svg')).toBeInTheDocument()
    })

    it('hides the Rep Graph icon link when reputation is hidden (non-voter, non-author)', () => {
      render(<WriteupDisplay writeup={mockWriteup} user={mockUser} />)

      expect(screen.queryByRole('link', { name: /reputation graph/i })).not.toBeInTheDocument()
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

  // Regression coverage for #4052 (cool) and #3613 (vote): the C? / vote
  // buttons must check the user's safety preference and pop a confirmation
  // modal instead of acting immediately. The fields live on the global
  // e2.user (Application.pm fills coolsafety + votesafety there); these
  // tests pin the contract WriteupDisplay relies on.
  describe('cool / vote confirmation safety prefs', () => {
    const writeupByOther = {
      ...mockWriteup,
      node_id: 123,
      author: { node_id: 999, title: 'someoneelse' }
    }

    beforeEach(() => {
      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        json: () => Promise.resolve({ success: true })
      })
    })
    afterEach(() => {
      delete global.fetch
    })

    it('opens cool confirmation modal when user.coolsafety is 1', () => {
      const userWithCoolsafety = {
        node_id: 789, is_guest: false, is_editor: false,
        coolsleft: 5, coolsafety: 1
      }
      const { container } = render(
        <WriteupDisplay writeup={writeupByOther} user={userWithCoolsafety} />
      )

      const coolLink = container.querySelector('.writeup-cool-action')
      expect(coolLink).toBeInTheDocument()
      fireEvent.click(coolLink)

      expect(screen.getByTestId('confirm-action-modal')).toHaveTextContent('Confirm C!')
      expect(global.fetch).not.toHaveBeenCalled()
    })

    it('cools immediately when user.coolsafety is missing (the pre-fix bug)', () => {
      const userWithoutCoolsafety = {
        node_id: 789, is_guest: false, is_editor: false,
        coolsleft: 5
      }
      const { container } = render(
        <WriteupDisplay writeup={writeupByOther} user={userWithoutCoolsafety} />
      )

      fireEvent.click(container.querySelector('.writeup-cool-action'))

      expect(screen.queryByTestId('confirm-action-modal')).not.toBeInTheDocument()
      expect(global.fetch).toHaveBeenCalled()
    })

    it('opens vote confirmation modal when user.votesafety is 1', () => {
      const userWithVotesafety = {
        node_id: 789, is_guest: false, is_editor: false,
        votesleft: 10, votesafety: 1
      }
      const { container } = render(
        <WriteupDisplay writeup={writeupByOther} user={userWithVotesafety} />
      )

      const upvoteBtn = container.querySelectorAll('.wu_vote button')[0]
      expect(upvoteBtn).toBeInTheDocument()
      fireEvent.click(upvoteBtn)

      expect(screen.getByTestId('confirm-action-modal')).toHaveTextContent(/Confirm Upvote/)
      expect(global.fetch).not.toHaveBeenCalled()
    })

    it('votes immediately when user.votesafety is missing (the pre-fix bug)', () => {
      const userWithoutVotesafety = {
        node_id: 789, is_guest: false, is_editor: false,
        votesleft: 10
      }
      const { container } = render(
        <WriteupDisplay writeup={writeupByOther} user={userWithoutVotesafety} />
      )

      fireEvent.click(container.querySelectorAll('.wu_vote button')[0])

      expect(screen.queryByTestId('confirm-action-modal')).not.toBeInTheDocument()
      expect(global.fetch).toHaveBeenCalled()
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

  describe('message modal', () => {
    it('pre-populates message with "re: (parent title)" when clicking message button', () => {
      const writeupWithParent = {
        ...mockWriteup,
        parent: { title: 'My Test Node Title' }
      }

      const { container } = render(<WriteupDisplay writeup={writeupWithParent} user={mockUser} />)

      // Find and click the message button (envelope icon)
      // Title is dynamic: "Message ${author.title}"
      const messageButton = screen.getByTitle(`Message ${writeupWithParent.author.title}`)
      expect(messageButton).toBeInTheDocument()

      fireEvent.click(messageButton)

      // Check the MessageModal received the correct initialMessage
      const modal = screen.getByTestId('message-modal')
      expect(modal).toHaveAttribute('data-initial-message', 're: My Test Node Title\n\n')
    })

    it('passes empty initialMessage when writeup has no parent', () => {
      const writeupWithoutParent = {
        ...mockWriteup,
        parent: null
      }

      const { container } = render(<WriteupDisplay writeup={writeupWithoutParent} user={mockUser} />)

      // Find and click the message button
      const messageButton = screen.getByTitle(`Message ${writeupWithoutParent.author.title}`)
      expect(messageButton).toBeInTheDocument()

      fireEvent.click(messageButton)

      // Check the MessageModal received empty initialMessage
      const modal = screen.getByTestId('message-modal')
      expect(modal).toHaveAttribute('data-initial-message', '')
    })

    describe('editor writeup feedback', () => {
      const editorUser = { node_id: 789, is_guest: false, is_editor: true }

      beforeEach(() => {
        global.fetch = jest.fn().mockImplementation((url) => {
          if (url === '/api/messages/create') {
            return Promise.resolve({
              ok: true,
              json: () => Promise.resolve({ successes: 1, errors: [], ignores: 0 })
            })
          }
          if (url.startsWith('/api/nodenotes/')) {
            return Promise.resolve({
              ok: true,
              json: () => Promise.resolve({ success: true })
            })
          }
          return Promise.reject(new Error('unexpected fetch: ' + url))
        })
      })

      afterEach(() => {
        delete global.fetch
      })

      it('exposes the feedback checkbox to MessageModal when the viewer is an editor', () => {
        render(<WriteupDisplay writeup={mockWriteup} user={editorUser} />)
        fireEvent.click(screen.getByTitle(`Message ${mockWriteup.author.title}`))
        expect(screen.getByTestId('message-modal')).toHaveAttribute('data-show-feedback', '1')
      })

      it('hides the feedback checkbox for non-editor viewers', () => {
        render(<WriteupDisplay writeup={mockWriteup} user={mockUser} />)
        fireEvent.click(screen.getByTitle(`Message ${mockWriteup.author.title}`))
        expect(screen.getByTestId('message-modal')).toHaveAttribute('data-show-feedback', '0')
      })

      it('posts a nodenote on the writeup when editor sends with feedback checked', async () => {
        render(<WriteupDisplay writeup={mockWriteup} user={editorUser} />)
        fireEvent.click(screen.getByTitle(`Message ${mockWriteup.author.title}`))
        fireEvent.click(screen.getByTestId('message-modal__send-feedback'))

        await waitFor(() => {
          expect(global.fetch).toHaveBeenCalledWith(
            `/api/nodenotes/${mockWriteup.node_id}/create`,
            expect.objectContaining({
              method: 'POST',
              body: JSON.stringify({ notetext: 'looks good' })
            })
          )
        })
      })

      it('does NOT post a nodenote when editor unchecks the feedback box', async () => {
        render(<WriteupDisplay writeup={mockWriteup} user={editorUser} />)
        fireEvent.click(screen.getByTitle(`Message ${mockWriteup.author.title}`))
        fireEvent.click(screen.getByTestId('message-modal__send-plain'))

        await waitFor(() => {
          // /api/messages/create still fires
          expect(global.fetch).toHaveBeenCalledWith('/api/messages/create', expect.anything())
        })
        const nodenoteCalls = global.fetch.mock.calls.filter(([url]) => url.startsWith('/api/nodenotes/'))
        expect(nodenoteCalls).toHaveLength(0)
      })
    })
  })

  describe('drafts: feedback mail button + gear gating', () => {
    const editorUser = { node_id: 789, is_guest: false, is_editor: true }

    it('renders the mail button on a draft for editor viewers', () => {
      render(<WriteupDisplay writeup={mockWriteup} user={editorUser} isDraft />)
      expect(screen.getByTitle(/Send feedback to/)).toBeInTheDocument()
    })

    it('opens the MessageModal when the mail button on a draft is clicked', () => {
      render(<WriteupDisplay writeup={mockWriteup} user={editorUser} isDraft />)
      fireEvent.click(screen.getByTitle(/Send feedback to/))
      expect(screen.getByTestId('message-modal')).toBeInTheDocument()
    })

    it('passes showFeedbackOption to MessageModal for editor draft messaging', () => {
      render(<WriteupDisplay writeup={mockWriteup} user={editorUser} isDraft />)
      fireEvent.click(screen.getByTitle(/Send feedback to/))
      expect(screen.getByTestId('message-modal')).toHaveAttribute('data-show-feedback', '1')
    })

    it('hides the mail button when the draft viewer IS the author', () => {
      // canMessage gates on !isAuthor — viewer.node_id === author.node_id
      const sameAuthor = { ...mockUser, node_id: mockWriteup.author.node_id }
      render(<WriteupDisplay writeup={mockWriteup} user={sameAuthor} isDraft />)
      expect(screen.queryByTitle(/Send feedback to/)).not.toBeInTheDocument()
    })

    it('does NOT render the gear on drafts unless showAdminToolsOverride is set', () => {
      render(<WriteupDisplay writeup={mockWriteup} user={editorUser} isDraft onAdminGearClick={() => {}} />)
      // Gear button uses title="Draft tools"
      expect(screen.queryByTitle('Draft tools')).not.toBeInTheDocument()
    })

    it('renders the gear on drafts when parent opts in via showAdminToolsOverride', () => {
      render(
        <WriteupDisplay
          writeup={mockWriteup}
          user={editorUser}
          isDraft
          showAdminToolsOverride
          onAdminGearClick={() => {}}
        />
      )
      expect(screen.getByTitle('Draft tools')).toBeInTheDocument()
    })
  })
})
