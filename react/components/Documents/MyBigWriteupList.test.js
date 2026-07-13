import React from 'react'
import { render, waitFor } from '@testing-library/react'
import MyBigWriteupList from './MyBigWriteupList'

// Fully client-resolved (#4524): the Page is a pure gate. MyBigWriteupList reads usersearch/orderby/
// raw/delimiter off the URL and fetches GET /api/my_big_writeup_list, which enforces the NoGuest gate
// and returns the list or an error state (React owns the copy for each state).

const OWN_LIST = {
  success: 1, username: 'someuser', user_id: 42, is_me: 0, show_rep: 1, total_count: 1,
  order_by: 'title ASC', raw_mode: 0, delimiter: '_',
  writeups: [
    { parent_e2node: 9, title: 'A Node', cooled: 2, publishtime: '2026-01-02 03:04:05', voted: 0,
      reputation: 10, total_votes: 12, upvotes: 11, downvotes: 1 }
  ]
}
const setSearch = (s) => { window.location.search = s }
const mockFetch = (p) => jest.fn(() => Promise.resolve({ json: () => Promise.resolve(p) }))

beforeEach(() => setSearch(''))
afterEach(() => { delete global.fetch; jest.restoreAllMocks() })

describe('MyBigWriteupList (fetch-driven)', () => {
  it('fetches the API and renders the writeup table with rep', async () => {
    global.fetch = mockFetch(OWN_LIST)
    const { container } = render(<MyBigWriteupList user={{ admin: false }} />)
    await waitFor(() => expect(container.querySelector('.my-big-writeup-list__table')).toBeTruthy())
    expect(global.fetch.mock.calls[0][0]).toContain('/api/my_big_writeup_list?')
    expect(container.textContent).toMatch(/A Node/)
    expect(container.textContent).toMatch(/\+11\/-1/) // upvotes/downvotes (show_rep)
  })

  it('carries usersearch/orderby/raw/delimiter from the URL into the fetch', async () => {
    setSearch('?usersearch=alice&orderby=' + encodeURIComponent('node.reputation DESC,title ASC') + '&raw=1&delimiter=%7C')
    global.fetch = mockFetch({ ...OWN_LIST, username: 'alice', raw_mode: 1, delimiter: '|' })
    render(<MyBigWriteupList user={{ admin: true }} />)
    await waitFor(() => expect(global.fetch).toHaveBeenCalled())
    const url = global.fetch.mock.calls[0][0]
    expect(url).toContain('usersearch=alice')
    expect(url).toContain('raw=1')
    expect(url).toContain('delimiter=%7C')
  })

  it('renders the guest state message', async () => {
    global.fetch = mockFetch({ success: 0, state: 'guest' })
    const { container } = render(<MyBigWriteupList user={{}} />)
    await waitFor(() => expect(container.textContent).toMatch(/need an account/i))
  })

  it('maps error states to copy (user_not_found interpolates the name)', async () => {
    global.fetch = mockFetch({ success: 0, state: 'user_not_found', username: 'ghost' })
    const { container } = render(<MyBigWriteupList user={{}} />)
    await waitFor(() => expect(container.textContent).toMatch(/User 'ghost' doesn't exist/))
  })

  it('renders the EDB easter-egg copy from its state', async () => {
    global.fetch = mockFetch({ success: 0, state: 'edb', username: 'EDB' })
    const { container } = render(<MyBigWriteupList user={{}} />)
    await waitFor(() => expect(container.textContent).toMatch(/G r o w l/))
  })

  it('shows a loading state before the fetch resolves', () => {
    global.fetch = jest.fn(() => new Promise(() => {}))
    const { container } = render(<MyBigWriteupList user={{}} />)
    expect(container.textContent).toMatch(/Loading writeups/i)
  })
})

describe('MyBigWriteupList admin role gating (reads user.admin)', () => {
  it('admin sees the user-search input', async () => {
    global.fetch = mockFetch({ ...OWN_LIST, total_count: 0, writeups: [] })
    const { container } = render(<MyBigWriteupList user={{ admin: true, editor: true }} />)
    await waitFor(() => expect(container.textContent).toContain('Search for user:'))
  })

  it('non-admin gets "For: <username>" instead of the search input', async () => {
    global.fetch = mockFetch({ ...OWN_LIST, total_count: 0, writeups: [] })
    const { container } = render(<MyBigWriteupList user={{ admin: false, editor: false }} />)
    await waitFor(() => expect(container.querySelector('.my-big-writeup-list__form-container')).toBeTruthy())
    expect(container.textContent).not.toContain('Search for user:')
    expect(container.textContent).toContain('For: someuser')
  })

  it('renders without crashing when user is undefined', async () => {
    global.fetch = mockFetch({ ...OWN_LIST, total_count: 0, writeups: [] })
    const { container } = render(<MyBigWriteupList user={undefined} />)
    await waitFor(() => expect(container.querySelector('.my-big-writeup-list__form-container')).toBeTruthy())
    expect(container.textContent).not.toContain('Search for user:')
  })
})

// #4524 follow-up: the table header now has one label per column (5), not a colSpan=2 "Rep", and the
// C! column shows an em-dash placeholder at zero cools so it visibly holds its place (was reading
// as an off-by-one).
describe('MyBigWriteupList table layout', () => {
  const TWO = {
    success: 1, username: 'someuser', user_id: 42, is_me: 1, show_rep: 1, total_count: 2,
    order_by: 'title ASC', raw_mode: 0, delimiter: '_',
    writeups: [
      { parent_e2node: 9, title: 'Cooled One (thing)', cooled: 3, publishtime: '2026-01-02 03:04:05',
        voted: 0, reputation: 20, total_votes: 24, upvotes: 22, downvotes: 2 },
      { parent_e2node: 10, title: 'No Cools (idea)', cooled: 0, publishtime: '2026-01-03 03:04:05',
        voted: 0, reputation: 5, total_votes: 7, upvotes: 6, downvotes: 1 }
    ]
  }

  it('the header has 5 one-per-column labels (no colSpan)', async () => {
    global.fetch = mockFetch(TWO)
    const { container } = render(<MyBigWriteupList user={{ admin: false }} />)
    await waitFor(() => expect(container.querySelector('.my-big-writeup-list__table')).toBeTruthy())
    const ths = [...container.querySelectorAll('.my-big-writeup-list__table thead th')]
    expect(ths).toHaveLength(5)
    expect(ths.every((th) => !th.getAttribute('colspan'))).toBe(true)
    const labels = ths.map((th) => th.textContent.trim())
    expect(labels[0]).toMatch(/Writeup Title/)
    expect(labels[1]).toBe('C!')
    expect(labels[2]).toBe('Rep')
    expect(labels[3]).toMatch(/\+/) // the +/- column
    expect(labels[4]).toBe('Published')
  })

  it('each data row spans 5 grid columns', async () => {
    global.fetch = mockFetch(TWO)
    const { container } = render(<MyBigWriteupList user={{ admin: false }} />)
    await waitFor(() => expect(container.querySelector('.my-big-writeup-list__table tbody tr')).toBeTruthy())
    const rows = [...container.querySelectorAll('.my-big-writeup-list__table tbody tr')]
    for (const tr of rows) {
      const cols = [...tr.querySelectorAll('td')].reduce((n, td) => n + (parseInt(td.getAttribute('colspan'), 10) || 1), 0)
      expect(cols).toBe(5)
    }
  })

  it('the C! column shows the count when cooled, and an em-dash placeholder at zero', async () => {
    global.fetch = mockFetch(TWO)
    const { container } = render(<MyBigWriteupList user={{ admin: false }} />)
    await waitFor(() => expect(container.querySelector('.my-big-writeup-list__table')).toBeTruthy())
    const rows = [...container.querySelectorAll('.my-big-writeup-list__table tbody tr')]
    // row 0 (cooled 3): its C! cell (2nd) reads "3C!"
    expect(rows[0].querySelectorAll('td')[1].textContent).toContain('3C!')
    // row 1 (cooled 0): its C! cell shows the muted em-dash placeholder, not empty
    const zeroCell = rows[1].querySelectorAll('td')[1]
    expect(zeroCell.textContent.trim()).not.toBe('')
    expect(zeroCell.querySelector('.my-big-writeup-list__muted')).toBeTruthy()
  })
})
