import React from 'react'
import { render, waitFor, fireEvent } from '@testing-library/react'
import ReputationGraph from './ReputationGraph'

// Fully client-resolved (#4504): the Page ships only { type, layout }. ReputationGraph reads the
// writeup `id` off the URL and fetches GET /api/reputation/votes, which returns writeup + author +
// months. These tests drive that flow: URL -> fetch -> render (or friendly error).

const MONTHS = [
  { year: 2026, month: 1, label: '1/2026', upvotes: 3, downvotes: -1, reputation: 2, is_january: true },
  { year: 2026, month: 2, label: '2/2026', upvotes: 5, downvotes: -2, reputation: 3, is_january: false }
]
const OK_PAYLOAD = {
  success: true,
  data: {
    writeup_id: 123,
    writeup: { node_id: 123, title: 'My Writeup', publishtime: '2026-01-01 00:00:00' },
    author: { node_id: 456, title: 'someauthor' },
    months: MONTHS
  }
}

// test-setup.js replaces window.location with a plain object, so set .search directly (pushState is a no-op).
const setSearch = (search) => { window.location.search = search }
const mockFetch = (payload) =>
  jest.fn(() => Promise.resolve({ json: () => Promise.resolve(payload) }))

beforeEach(() => {
  setSearch('?id=123')
})
afterEach(() => {
  delete global.fetch
  jest.restoreAllMocks()
})

describe('ReputationGraph fetch-driven resolution (#4504)', () => {
  it('reads id off the URL and fetches /api/reputation/votes with it', async () => {
    global.fetch = mockFetch(OK_PAYLOAD)
    render(<ReputationGraph data={{ type: 'reputation_graph', layout: 'vertical' }} user={{}} />)
    await waitFor(() => expect(global.fetch).toHaveBeenCalledTimes(1))
    expect(global.fetch.mock.calls[0][0]).toContain('/api/reputation/votes?writeup_id=123')
  })

  it('renders the writeup + author from the API response', async () => {
    global.fetch = mockFetch(OK_PAYLOAD)
    const { container } = render(<ReputationGraph data={{ layout: 'vertical' }} user={{}} />)
    await waitFor(() => expect(container.textContent).toMatch(/My Writeup/))
    expect(container.textContent).toMatch(/someauthor/)
    const links = container.querySelectorAll('a.reputation-graph__link')
    expect(links[0].getAttribute('href')).toBe('/?node_id=123')
    expect(links[1].getAttribute('href')).toBe('/?node_id=456')
  })

  it('shows a loading state before the fetch resolves', () => {
    let resolve
    global.fetch = jest.fn(() => new Promise((r) => { resolve = () => r({ json: () => Promise.resolve(OK_PAYLOAD) }) }))
    const { container } = render(<ReputationGraph data={{ layout: 'vertical' }} user={{}} />)
    expect(container.textContent).toMatch(/Loading reputation data/i)
    resolve() // let the promise settle so the test doesn't leak
  })
})

describe('ReputationGraph layouts', () => {
  beforeEach(() => {
    global.fetch = mockFetch(OK_PAYLOAD)
  })

  it('renders the vertical (table) layout', async () => {
    const { container } = render(<ReputationGraph data={{ layout: 'vertical' }} user={{}} />)
    await waitFor(() => expect(container.querySelector('.reputation-graph__vertical-table')).toBeTruthy())
    expect(container.querySelector('.reputation-graph__horizontal-table')).toBeNull()
    // one data row per month
    expect(container.querySelectorAll('.reputation-graph__vertical-table tbody tr').length).toBe(2)
  })

  it('renders the horizontal (bar) layout when layout=horizontal', async () => {
    const { container } = render(<ReputationGraph data={{ layout: 'horizontal' }} user={{}} />)
    await waitFor(() => expect(container.querySelector('.reputation-graph__horizontal-table')).toBeTruthy())
    expect(container.querySelector('.reputation-graph__vertical-table')).toBeNull()
  })

  it('defaults to vertical when layout is absent', async () => {
    const { container } = render(<ReputationGraph data={{}} user={{}} />)
    await waitFor(() => expect(container.querySelector('.reputation-graph__vertical-table')).toBeTruthy())
  })

  it('renders the cumulative reputation number under each bar in the chart view', async () => {
    const { container } = render(<ReputationGraph data={{ layout: 'horizontal' }} user={{}} />)
    await waitFor(() => expect(container.querySelector('.reputation-graph__horizontal-table')).toBeTruthy())
    const values = [...container.querySelectorAll('.reputation-graph__value-cell')].map((c) => c.textContent)
    expect(values).toEqual(['2', '3']) // one per month, from months[].reputation
  })

  it('marks the year at January columns in the chart view', async () => {
    const { container } = render(<ReputationGraph data={{ layout: 'horizontal' }} user={{}} />)
    await waitFor(() => expect(container.querySelector('.reputation-graph__label-row')).toBeTruthy())
    const labels = [...container.querySelectorAll('.reputation-graph__label-cell')].map((c) => c.textContent)
    expect(labels).toEqual(['2026', '']) // month 1 is January (year shown), month 2 blank
  })
})

describe('ReputationGraph view-toggle pill (consolidated layouts #4504)', () => {
  beforeEach(() => {
    global.fetch = mockFetch(OK_PAYLOAD)
  })

  it('seeds the active pill from the page-provided layout (vertical node)', async () => {
    const { container } = render(<ReputationGraph data={{ layout: 'vertical' }} user={{}} />)
    await waitFor(() => expect(container.querySelector('.reputation-graph__vertical-table')).toBeTruthy())
    const pills = container.querySelectorAll('.reputation-graph__view-pill')
    expect(pills[0].textContent).toBe('Table')
    expect(pills[0].getAttribute('aria-pressed')).toBe('true')
    expect(pills[1].getAttribute('aria-pressed')).toBe('false')
  })

  it('seeds the active pill from the page-provided layout (horizontal node)', async () => {
    const { container } = render(<ReputationGraph data={{ layout: 'horizontal' }} user={{}} />)
    await waitFor(() => expect(container.querySelector('.reputation-graph__horizontal-table')).toBeTruthy())
    const pills = container.querySelectorAll('.reputation-graph__view-pill')
    expect(pills[1].textContent).toBe('Chart')
    expect(pills[1].getAttribute('aria-pressed')).toBe('true')
  })

  it('switches from table to chart and back on pill click, without re-fetching', async () => {
    const { container, getByText } = render(<ReputationGraph data={{ layout: 'vertical' }} user={{}} />)
    await waitFor(() => expect(container.querySelector('.reputation-graph__vertical-table')).toBeTruthy())
    expect(global.fetch).toHaveBeenCalledTimes(1)

    fireEvent.click(getByText('Chart'))
    expect(container.querySelector('.reputation-graph__horizontal-table')).toBeTruthy()
    expect(container.querySelector('.reputation-graph__vertical-table')).toBeNull()

    fireEvent.click(getByText('Table'))
    expect(container.querySelector('.reputation-graph__vertical-table')).toBeTruthy()
    expect(container.querySelector('.reputation-graph__horizontal-table')).toBeNull()

    // toggling is a client-side view switch, not a new API round-trip
    expect(global.fetch).toHaveBeenCalledTimes(1)
  })
})

describe('ReputationGraph friendly errors (mapped from API error strings)', () => {
  it('maps Access denied to the "you haven\'t voted" guidance', async () => {
    global.fetch = mockFetch({ success: false, error: 'Access denied' })
    const { container } = render(<ReputationGraph data={{ layout: 'vertical' }} user={{}} />)
    await waitFor(() => expect(container.textContent).toMatch(/haven't voted on that writeup/i))
    expect(container.querySelector('.reputation-graph__vertical-table')).toBeNull()
  })

  it('maps Node is not a writeup to the writeups-only guidance', async () => {
    global.fetch = mockFetch({ success: false, error: 'Node is not a writeup' })
    const { container } = render(<ReputationGraph data={{ layout: 'vertical' }} user={{}} />)
    await waitFor(() => expect(container.textContent).toMatch(/only view the reputation graph for writeups/i))
  })

  it('maps Invalid writeup ID / not found to the "not a valid node" guidance', async () => {
    global.fetch = mockFetch({ success: false, error: 'Writeup not found' })
    const { container } = render(<ReputationGraph data={{ layout: 'vertical' }} user={{}} />)
    await waitFor(() => expect(container.textContent).toMatch(/Not a valid node/i))
  })

  it('shows the not-a-valid-node error and never fetches when the URL has no id', async () => {
    setSearch('')
    global.fetch = mockFetch(OK_PAYLOAD)
    const { container } = render(<ReputationGraph data={{ layout: 'vertical' }} user={{}} />)
    await waitFor(() => expect(container.textContent).toMatch(/Not a valid node/i))
    expect(global.fetch).not.toHaveBeenCalled()
  })

  it('surfaces a network error when the fetch rejects', async () => {
    global.fetch = jest.fn(() => Promise.reject(new Error('boom')))
    const { container } = render(<ReputationGraph data={{ layout: 'vertical' }} user={{}} />)
    await waitFor(() => expect(container.textContent).toMatch(/Network error: boom/i))
  })
})

describe('ReputationGraph admin-note gating (from user prop)', () => {
  beforeEach(() => {
    global.fetch = mockFetch(OK_PAYLOAD)
  })

  it('shows the admin URL-append note when user.admin is true', async () => {
    const { container } = render(<ReputationGraph data={{ layout: 'vertical' }} user={{ admin: true }} />)
    await waitFor(() => expect(container.textContent).toMatch(/Admins can view the graph/))
  })

  it('hides the admin note when user.admin is false', async () => {
    const { container } = render(<ReputationGraph data={{ layout: 'vertical' }} user={{ admin: false }} />)
    await waitFor(() => expect(container.textContent).toMatch(/monthly reputation graph/i))
    expect(container.textContent).not.toMatch(/Admins can view the graph/)
  })

  it('does not crash when user prop is undefined (note hidden)', async () => {
    const { container } = render(<ReputationGraph data={{ layout: 'vertical' }} user={undefined} />)
    await waitFor(() => expect(container.textContent).toMatch(/monthly reputation graph/i))
    expect(container.textContent).not.toMatch(/Admins can view the graph/)
  })

  it('emits no React key warnings while rendering month rows', async () => {
    const errs = []
    jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    const { container } = render(<ReputationGraph data={{ layout: 'vertical' }} user={{}} />)
    await waitFor(() => expect(container.querySelector('.reputation-graph__vertical-table')).toBeTruthy())
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})
