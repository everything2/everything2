import React from 'react'
import { render, waitFor } from '@testing-library/react'
import UserSearch from './UserSearch'
import fixture from '../../__fixtures__/pagestate/everything_user_search.json'

// Fully client-resolved (#4506): the Page ships only { type }. UserSearch reads its initial search
// state (usersearch / orderby / page / filterhidden) off the URL and fetches results from
// /api/user_search, reusing the shared autofill (UserSearchInput -> /api/node_search).

// test-setup.js replaces window.location with a plain object, so set .search directly.
const setSearch = (search) => { window.location.search = search }

beforeEach(() => {
  setSearch('')
})
afterEach(() => {
  delete global.fetch
  jest.restoreAllMocks()
})

describe('UserSearch (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<UserSearch data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<UserSearch data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

describe('UserSearch URL-seeded initial state (#4506)', () => {
  const okResults = { writeups: [], total: 0, user: { title: 'root', node_id: 113 } }
  const mockFetch = () => jest.fn(() => Promise.resolve({ ok: true, json: () => Promise.resolve(okResults) }))

  it('seeds the username from ?usersearch= and fetches results for it', async () => {
    setSearch('?usersearch=root')
    global.fetch = mockFetch()
    render(<UserSearch data={{}} user={{}} />)
    await waitFor(() => expect(global.fetch).toHaveBeenCalled())
    const url = global.fetch.mock.calls[0][0]
    expect(url).toContain('/api/user_search/?')
    expect(url).toContain('username=root')
    expect(url).toContain('orderby=publishtime_desc') // default
    expect(url).toContain('page=1')
    expect(url).toContain('filter_hidden=0')
  })

  it('carries orderby, page, and filterhidden through from the URL', async () => {
    setSearch('?usersearch=root&orderby=reputation_desc&page=3&filterhidden=1')
    global.fetch = mockFetch()
    render(<UserSearch data={{}} user={{}} />)
    await waitFor(() => expect(global.fetch).toHaveBeenCalled())
    const url = global.fetch.mock.calls[0][0]
    expect(url).toContain('orderby=reputation_desc')
    expect(url).toContain('page=3')
    expect(url).toContain('filter_hidden=1')
  })

  it('maps a legacy SQL-string orderby to the current short code', async () => {
    setSearch('?usersearch=root&orderby=' + encodeURIComponent('node.title ASC'))
    global.fetch = mockFetch()
    render(<UserSearch data={{}} user={{}} />)
    await waitFor(() => expect(global.fetch).toHaveBeenCalled())
    expect(global.fetch.mock.calls[0][0]).toContain('orderby=title_asc')
  })

  it('falls back to page 1 / filter 0 when the URL values are non-numeric', async () => {
    setSearch('?usersearch=root&page=abc&filterhidden=xyz')
    global.fetch = mockFetch()
    render(<UserSearch data={{}} user={{}} />)
    await waitFor(() => expect(global.fetch).toHaveBeenCalled())
    const url = global.fetch.mock.calls[0][0]
    expect(url).toContain('page=1')
    expect(url).toContain('filter_hidden=0')
  })

  it('does not fetch when the URL carries no username (empty state)', async () => {
    setSearch('')
    global.fetch = mockFetch()
    render(<UserSearch data={{}} user={{}} />)
    // give any effect a tick to (not) fire
    await new Promise((r) => setTimeout(r, 0))
    expect(global.fetch).not.toHaveBeenCalled()
  })

  it('ignores server-provided data.initial* (Page is now a pure gate)', async () => {
    setSearch('?usersearch=fromurl')
    global.fetch = mockFetch()
    render(<UserSearch data={{ initialUsername: 'fromserver', initialPage: 9 }} user={{}} />)
    await waitFor(() => expect(global.fetch).toHaveBeenCalled())
    const url = global.fetch.mock.calls[0][0]
    expect(url).toContain('username=fromurl')
    expect(url).not.toContain('username=fromserver')
    expect(url).toContain('page=1')
  })
})
