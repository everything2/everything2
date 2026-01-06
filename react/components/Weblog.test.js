import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import '@testing-library/jest-dom'
import Weblog from './Weblog'

// Mock fetch
global.fetch = jest.fn()

// Mock confirm
window.confirm = jest.fn(() => true)

// Sample weblog data
const sampleEntries = [
  {
    to_node: 123,
    title: 'Test Writeup 1',
    type: 'writeup',
    doctext: '<p>This is test content for writeup 1</p>',
    linkedtime: '2025-01-01 12:00:00',
    linkedby: { node_id: 456, title: 'LinkUser' },
    author: { node_id: 789, title: 'AuthorUser' },
    author_user: 789
  },
  {
    to_node: 124,
    title: 'Test Writeup 2',
    type: 'writeup',
    doctext: '<p>This is test content for writeup 2</p>',
    linkedtime: '2025-01-02 12:00:00',
    linkedby: { node_id: 789, title: 'AuthorUser' },
    author: { node_id: 789, title: 'AuthorUser' },
    author_user: 789
  }
]

const sampleWeblog = {
  entries: sampleEntries,
  has_more: false,
  can_remove: false,
  weblog_id: 999
}

describe('Weblog Component', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  it('renders nothing when weblog is null', () => {
    const { container } = render(<Weblog weblog={null} />)
    expect(container.firstChild).toBeNull()
  })

  it('renders nothing when entries are empty', () => {
    const { container } = render(<Weblog weblog={{ entries: [], has_more: false, can_remove: false, weblog_id: 999 }} />)
    expect(container.firstChild).toBeNull()
  })

  it('renders weblog entries', () => {
    render(<Weblog weblog={sampleWeblog} />)

    expect(screen.getByText('Test Writeup 1')).toBeInTheDocument()
    expect(screen.getByText('Test Writeup 2')).toBeInTheDocument()
  })

  it('renders author names', () => {
    render(<Weblog weblog={sampleWeblog} />)

    // AuthorUser appears multiple times (as author and linker)
    const authorLinks = screen.getAllByText('AuthorUser')
    expect(authorLinks.length).toBeGreaterThan(0)
  })

  it('shows linked by attribution when linker is different from author', () => {
    render(<Weblog weblog={sampleWeblog} />)

    // First entry has different linker (LinkUser) from author (AuthorUser)
    expect(screen.getByText('LinkUser')).toBeInTheDocument()
    expect(screen.getByText(/linked by/i)).toBeInTheDocument()
  })

  it('does not show linked by when linker is same as author', () => {
    const singleEntry = {
      entries: [{
        to_node: 124,
        title: 'Self Linked',
        type: 'writeup',
        doctext: '<p>Content</p>',
        linkedtime: '2025-01-02 12:00:00',
        linkedby: { node_id: 789, title: 'SameUser' },
        author: { node_id: 789, title: 'SameUser' },
        author_user: 789
      }],
      has_more: false,
      can_remove: false,
      weblog_id: 999
    }

    render(<Weblog weblog={singleEntry} />)

    // Should not show "linked by" for self-linked entries
    expect(screen.queryByText(/linked by/i)).toBeNull()
  })

  it('does not show remove button when can_remove is false', () => {
    render(<Weblog weblog={sampleWeblog} />)

    expect(screen.queryByText(/remove/i)).toBeNull()
  })

  it('shows remove button when can_remove is true', () => {
    const weblogWithRemove = { ...sampleWeblog, can_remove: true }
    render(<Weblog weblog={weblogWithRemove} />)

    const removeButtons = screen.getAllByText('remove')
    expect(removeButtons.length).toBe(2) // One for each entry
  })

  it('does not show load more button when has_more is false', () => {
    render(<Weblog weblog={sampleWeblog} />)

    expect(screen.queryByText(/load older entries/i)).toBeNull()
  })

  it('shows load more button when has_more is true', () => {
    const weblogWithMore = { ...sampleWeblog, has_more: true }
    render(<Weblog weblog={weblogWithMore} />)

    expect(screen.getByText(/load older entries/i)).toBeInTheDocument()
  })

  it('loads more entries when button is clicked', async () => {
    const weblogWithMore = { ...sampleWeblog, has_more: true }

    // Mock successful API response
    fetch.mockResolvedValueOnce({
      json: () => Promise.resolve({
        success: true,
        entries: [{
          to_node: 125,
          title: 'Loaded Writeup',
          type: 'writeup',
          doctext: '<p>Loaded content</p>',
          linkedtime: '2025-01-03 12:00:00',
          linkedby: { node_id: 100, title: 'Loader' },
          author: { node_id: 100, title: 'Loader' },
          author_user: 100
        }],
        has_more: false
      })
    })

    render(<Weblog weblog={weblogWithMore} />)

    const loadMoreButton = screen.getByText(/load older entries/i)
    fireEvent.click(loadMoreButton)

    await waitFor(() => {
      expect(fetch).toHaveBeenCalledWith(
        '/api/weblog/999?limit=5&offset=2',
        { credentials: 'same-origin' }
      )
    })
  })

  it('renders title when provided', () => {
    render(<Weblog weblog={sampleWeblog} title="Test Weblog Title" />)

    expect(screen.getByText('Test Weblog Title')).toBeInTheDocument()
  })

  it('does not render title when not provided', () => {
    render(<Weblog weblog={sampleWeblog} />)

    expect(screen.queryByRole('heading', { level: 3 })).toBeNull()
  })

  it('formats dates correctly', () => {
    render(<Weblog weblog={sampleWeblog} />)

    // Dates should be formatted as Month Day, Year
    expect(screen.getByText(/January 1, 2025/i)).toBeInTheDocument()
    expect(screen.getByText(/January 2, 2025/i)).toBeInTheDocument()
  })
})

describe('Weblog Entry Removal', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  it('shows confirmation modal when remove is clicked', async () => {
    const weblogWithRemove = { ...sampleWeblog, can_remove: true }
    render(<Weblog weblog={weblogWithRemove} />)

    const removeButtons = screen.getAllByTitle('Remove from weblog')
    fireEvent.click(removeButtons[0])

    // Confirm modal should appear
    await waitFor(() => {
      expect(screen.getByText(/Remove Weblog Entry/i)).toBeInTheDocument()
    })
  })

  it('removes entry on successful API call', async () => {
    const weblogWithRemove = { ...sampleWeblog, can_remove: true }

    fetch.mockResolvedValueOnce({
      json: () => Promise.resolve({ success: true })
    })

    render(<Weblog weblog={weblogWithRemove} />)

    // Click remove
    const removeButtons = screen.getAllByTitle('Remove from weblog')
    fireEvent.click(removeButtons[0])

    // Confirm in modal
    await waitFor(() => {
      const confirmButton = screen.getByText('Remove')
      fireEvent.click(confirmButton)
    })

    // Verify API was called
    await waitFor(() => {
      expect(fetch).toHaveBeenCalledWith(
        '/api/weblog/999/123',
        expect.objectContaining({ method: 'DELETE' })
      )
    })
  })
})
