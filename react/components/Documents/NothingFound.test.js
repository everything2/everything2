import React from 'react'
import { render, screen } from '@testing-library/react'
import NothingFound from './NothingFound'

// Mock the GoogleAds component
jest.mock('../Layout/GoogleAds', () => ({
  InContentAd: ({ show }) => show ? <div data-testid="in-content-ad">Ad</div> : null
}))

describe('NothingFound', () => {
  const defaultProps = {
    data: {
      search_term: 'nonexistent',
      is_guest: false,
      is_editor: false,
      lastnode_id: 12345,
      best_entries: []
    },
    user: { node_id: 123 }
  }

  it('renders nothing found message', () => {
    render(<NothingFound {...defaultProps} />)
    expect(screen.getByText(/Sorry, but nothing matching "nonexistent" was found/)).toBeInTheDocument()
  })

  it('shows nuke message when was_nuke is true', () => {
    render(<NothingFound data={{ was_nuke: true }} user={defaultProps.user} />)
    expect(screen.getByText(/It looks like you nuked it/)).toBeInTheDocument()
  })

  it('shows generic message when no search term', () => {
    render(<NothingFound data={{ search_term: '' }} user={defaultProps.user} />)
    expect(screen.getByText(/There's nothing there/i)).toBeInTheDocument()
  })

  describe('external links', () => {
    it('shows external link when is_url is true', () => {
      render(<NothingFound data={{
        ...defaultProps.data,
        is_url: true,
        external_link: 'https://example.com'
      }} user={defaultProps.user} />)
      expect(screen.getByText('https://example.com')).toBeInTheDocument()
    })
  })

  describe('guest experience', () => {
    it('shows login message for guests', () => {
      render(<NothingFound data={{ ...defaultProps.data, is_guest: true }} user={defaultProps.user} />)
      expect(screen.getByRole('link', { name: 'Log in' })).toBeInTheDocument()
      expect(screen.getByRole('link', { name: 'register here' })).toBeInTheDocument()
    })

    it('shows best entries for guests', () => {
      const best_entries = [
        { writeup_id: 1, node_id: 100, title: 'Best Entry 1', author: { title: 'Author1' } },
        { writeup_id: 2, node_id: 101, title: 'Best Entry 2', author: { title: 'Author2' } }
      ]
      render(<NothingFound data={{ ...defaultProps.data, is_guest: true, best_entries }} user={defaultProps.user} />)
      expect(screen.getByText('Best Entry 1')).toBeInTheDocument()
      expect(screen.getByText('Best Entry 2')).toBeInTheDocument()
    })

    it('shows best entries heading for guests', () => {
      const best_entries = [
        { writeup_id: 1, node_id: 100, title: 'Entry', author: { title: 'Author' } }
      ]
      render(<NothingFound data={{ ...defaultProps.data, is_guest: true, best_entries }} user={defaultProps.user} />)
      expect(screen.getByText(/here are some of our best entries/)).toBeInTheDocument()
    })

    it('shows author names in best entries', () => {
      const best_entries = [
        { writeup_id: 1, node_id: 100, title: 'Entry', author: { title: 'TestAuthor' } }
      ]
      render(<NothingFound data={{ ...defaultProps.data, is_guest: true, best_entries }} user={defaultProps.user} />)
      expect(screen.getByText('TestAuthor')).toBeInTheDocument()
    })

    it('shows excerpts in best entries', () => {
      const best_entries = [
        { writeup_id: 1, node_id: 100, title: 'Entry', author: { title: 'Author' }, excerpt: 'This is the excerpt text' }
      ]
      render(<NothingFound data={{ ...defaultProps.data, is_guest: true, best_entries }} user={defaultProps.user} />)
      expect(screen.getByText('This is the excerpt text')).toBeInTheDocument()
    })
  })

  describe('ads in best entries for guests', () => {
    it('shows ads every 4 items in best entries', () => {
      const best_entries = Array.from({ length: 10 }, (_, i) => ({
        writeup_id: i + 1,
        node_id: i + 100,
        title: `Best Entry ${i + 1}`,
        author: { title: `Author${i + 1}` }
      }))
      render(<NothingFound data={{ ...defaultProps.data, is_guest: true, best_entries }} user={defaultProps.user} />)
      // Ads should appear after items 4 and 8
      const ads = screen.getAllByTestId('in-content-ad')
      expect(ads).toHaveLength(2)
    })

    it('does not show ad after last item', () => {
      const best_entries = Array.from({ length: 4 }, (_, i) => ({
        writeup_id: i + 1,
        node_id: i + 100,
        title: `Best Entry ${i + 1}`,
        author: { title: `Author${i + 1}` }
      }))
      render(<NothingFound data={{ ...defaultProps.data, is_guest: true, best_entries }} user={defaultProps.user} />)
      // With exactly 4 items, no ad should show
      expect(screen.queryByTestId('in-content-ad')).not.toBeInTheDocument()
    })

    it('shows ad after 4th item when there are more', () => {
      const best_entries = Array.from({ length: 5 }, (_, i) => ({
        writeup_id: i + 1,
        node_id: i + 100,
        title: `Best Entry ${i + 1}`,
        author: { title: `Author${i + 1}` }
      }))
      render(<NothingFound data={{ ...defaultProps.data, is_guest: true, best_entries }} user={defaultProps.user} />)
      expect(screen.getAllByTestId('in-content-ad')).toHaveLength(1)
    })
  })

  describe('logged-in user experience', () => {
    it('shows search again form', () => {
      render(<NothingFound data={{ ...defaultProps.data, is_guest: false }} user={defaultProps.user} />)
      expect(screen.getByRole('button', { name: 'search' })).toBeInTheDocument()
    })

    it('shows create new buttons', () => {
      render(<NothingFound data={{ ...defaultProps.data, is_guest: false }} user={defaultProps.user} />)
      expect(screen.getByRole('button', { name: 'New draft' })).toBeInTheDocument()
      expect(screen.getByRole('button', { name: 'New node' })).toBeInTheDocument()
    })

    it('shows existing e2node link when it exists', () => {
      render(<NothingFound data={{
        ...defaultProps.data,
        is_guest: false,
        existing_e2node: { node_id: 999, title: 'Existing Node' }
      }} user={defaultProps.user} />)
      expect(screen.getByText('Existing Node')).toBeInTheDocument()
      expect(screen.getByText('already exists.')).toBeInTheDocument()
    })
  })

  describe('editor features', () => {
    it('shows tin opener link for editors when not active', () => {
      render(<NothingFound data={{
        ...defaultProps.data,
        show_tin_opener: true,
        tinopener_active: false
      }} user={defaultProps.user} />)
      expect(screen.getByText(/use the godly tin-opener/)).toBeInTheDocument()
    })

    it('shows tin opener message when active', () => {
      render(<NothingFound data={{
        ...defaultProps.data,
        show_tin_opener: true,
        tinopener_active: true,
        tin_opener_message: 'Draft found and displayed'
      }} user={defaultProps.user} />)
      expect(screen.getByText(/Draft found and displayed/)).toBeInTheDocument()
    })

    it('shows editor note for editors', () => {
      render(<NothingFound data={{
        ...defaultProps.data,
        is_guest: false,
        is_editor: true
      }} user={defaultProps.user} />)
      expect(screen.getByText(/Editorial Power/)).toBeInTheDocument()
    })
  })
})
