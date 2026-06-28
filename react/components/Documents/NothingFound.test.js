import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import NothingFound from './NothingFound'

// Mock the GoogleAds component
jest.mock('../Layout/GoogleAds', () => ({
  InContentAd: ({ show }) => show ? <div data-testid="in-content-ad">Ad</div> : null
}))

describe('NothingFound', () => {
  const defaultProps = {
    data: {
      search_term: 'nonexistent',
      lastnode_id: 12345,
      best_entries: []
    },
    user: { node_id: 123, guest: false }
  }

  const guestUser = { node_id: 0, guest: true }

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
      render(<NothingFound data={defaultProps.data} user={guestUser} />)
      expect(screen.getByRole('link', { name: 'Log in' })).toBeInTheDocument()
      expect(screen.getByRole('link', { name: 'register here' })).toBeInTheDocument()
    })

    it('shows best entries for guests', () => {
      const best_entries = [
        { writeup_id: 1, node_id: 100, title: 'Best Entry 1', author: { title: 'Author1' } },
        { writeup_id: 2, node_id: 101, title: 'Best Entry 2', author: { title: 'Author2' } }
      ]
      render(<NothingFound data={{ ...defaultProps.data, best_entries }} user={guestUser} />)
      expect(screen.getByText('Best Entry 1')).toBeInTheDocument()
      expect(screen.getByText('Best Entry 2')).toBeInTheDocument()
    })

    it('shows best entries heading for guests', () => {
      const best_entries = [
        { writeup_id: 1, node_id: 100, title: 'Entry', author: { title: 'Author' } }
      ]
      render(<NothingFound data={{ ...defaultProps.data, best_entries }} user={guestUser} />)
      expect(screen.getByText(/here are some of our best entries/)).toBeInTheDocument()
    })

    it('shows author names in best entries', () => {
      const best_entries = [
        { writeup_id: 1, node_id: 100, title: 'Entry', author: { title: 'TestAuthor' } }
      ]
      render(<NothingFound data={{ ...defaultProps.data, best_entries }} user={guestUser} />)
      expect(screen.getByText('TestAuthor')).toBeInTheDocument()
    })

    it('shows excerpts in best entries', () => {
      const best_entries = [
        { writeup_id: 1, node_id: 100, title: 'Entry', author: { title: 'Author' }, excerpt: 'This is the excerpt text' }
      ]
      render(<NothingFound data={{ ...defaultProps.data, best_entries }} user={guestUser} />)
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
      render(<NothingFound data={{ ...defaultProps.data, best_entries }} user={guestUser} />)
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
      render(<NothingFound data={{ ...defaultProps.data, best_entries }} user={guestUser} />)
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
      render(<NothingFound data={{ ...defaultProps.data, best_entries }} user={guestUser} />)
      expect(screen.getAllByTestId('in-content-ad')).toHaveLength(1)
    })
  })

  describe('logged-in user experience', () => {
    it('shows search again form', () => {
      render(<NothingFound data={defaultProps.data} user={defaultProps.user} />)
      expect(screen.getByRole('button', { name: 'search' })).toBeInTheDocument()
    })

    it('shows create new buttons', () => {
      render(<NothingFound data={defaultProps.data} user={defaultProps.user} />)
      expect(screen.getByRole('button', { name: 'New draft' })).toBeInTheDocument()
      expect(screen.getByRole('button', { name: 'New node' })).toBeInTheDocument()
    })

    it('shows existing e2node link when it exists', () => {
      render(<NothingFound data={{
        ...defaultProps.data,
        existing_e2node: { node_id: 999, title: 'Existing Node' }
      }} user={defaultProps.user} />)
      expect(screen.getByText('Existing Node')).toBeInTheDocument()
      expect(screen.getByText('already exists.')).toBeInTheDocument()
    })
  })

  // Migration from op=new to POST /api/node/create (#4340).
  describe('create-node API migration', () => {
    let originalLocation

    beforeEach(() => {
      originalLocation = window.location
      delete window.location
      window.location = { href: '' }
      global.fetch = jest.fn(() =>
        Promise.resolve({ ok: true, json: async () => ({ success: 1, node_id: 999 }) })
      )
    })

    afterEach(() => {
      window.location = originalLocation
      jest.restoreAllMocks()
    })

    const parseBody = (call) => JSON.parse(call[1].body)

    it('creates a draft via /api/node/create and redirects to /node/<id>', async () => {
      render(<NothingFound data={{ ...defaultProps.data, search_term: 'My Topic' }} user={defaultProps.user} />)

      fireEvent.change(screen.getAllByRole('textbox')[1], { target: { value: 'My Topic' } })
      fireEvent.click(screen.getByRole('button', { name: 'New draft' }))

      await waitFor(() => expect(global.fetch).toHaveBeenCalled())
      const call = global.fetch.mock.calls[0]
      expect(call[0]).toBe('/api/node/create')
      expect(parseBody(call)).toMatchObject({ type: 'draft', title: 'My Topic' })

      await waitFor(() => expect(window.location.href).toBe('/node/999'))
    })

    it('creates an e2node via /api/node/create', async () => {
      render(<NothingFound data={{ ...defaultProps.data, search_term: 'My Topic' }} user={defaultProps.user} />)

      fireEvent.change(screen.getAllByRole('textbox')[1], { target: { value: 'My Topic' } })
      fireEvent.click(screen.getByRole('button', { name: 'New node' }))

      await waitFor(() => expect(global.fetch).toHaveBeenCalled())
      const call = global.fetch.mock.calls[0]
      expect(call[0]).toBe('/api/node/create')
      expect(parseBody(call)).toMatchObject({ type: 'e2node', title: 'My Topic' })

      await waitFor(() => expect(window.location.href).toBe('/node/999'))
    })

    it('does not call the API when the title is empty', () => {
      render(<NothingFound data={{ ...defaultProps.data, search_term: '   ' }} user={defaultProps.user} />)

      fireEvent.change(screen.getAllByRole('textbox')[1], { target: { value: '   ' } })
      fireEvent.click(screen.getByRole('button', { name: 'New draft' }))

      expect(global.fetch).not.toHaveBeenCalled()
    })
  })

  // #4399: viewer role flags are read from the canonical `user` prop, not
  // duplicated keys in contentData. user.guest gates the guest vs logged-in view.
  describe('role gating via user prop (#4399)', () => {
    it('renders guest view when user.guest is true', () => {
      const { container } = render(<NothingFound data={defaultProps.data} user={guestUser} />)
      expect(container.textContent).toMatch(/Log in/)
      // Logged-in-only "Create new..." forms must not appear for guests.
      expect(screen.queryByRole('button', { name: 'New draft' })).not.toBeInTheDocument()
    })

    it('renders logged-in view when user.guest is false', () => {
      const { container } = render(<NothingFound data={defaultProps.data} user={{ node_id: 123, guest: false }} />)
      expect(container.textContent).not.toMatch(/If you .*Log in.* you could create/)
      expect(screen.getByRole('button', { name: 'New draft' })).toBeInTheDocument()
    })

    it('does not read is_guest from data (dedup) — data.is_guest is ignored', () => {
      // Stale/absent data.is_guest must not drive the view; only user.guest does.
      const { container } = render(
        <NothingFound data={{ ...defaultProps.data, is_guest: true }} user={{ node_id: 123, guest: false }} />
      )
      // user.guest === false wins: logged-in form shows.
      expect(screen.getByRole('button', { name: 'New draft' })).toBeInTheDocument()
      expect(container.textContent).toMatch(/create a new draft or e2node/)
    })

    it('treats a guest viewer (user.guest true) as guest even if data lacks is_guest', () => {
      const { container } = render(<NothingFound data={defaultProps.data} user={{ node_id: 0, guest: true }} />)
      expect(container.textContent).toMatch(/register here/)
    })

    it('does not crash when user is undefined (treats as non-guest)', () => {
      const { container } = render(<NothingFound data={defaultProps.data} user={undefined} />)
      // No throw; falls back to the logged-in/create view.
      expect(container.textContent).toMatch(/Sorry, but nothing matching/)
      expect(screen.getByRole('button', { name: 'New draft' })).toBeInTheDocument()
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
  })
})
