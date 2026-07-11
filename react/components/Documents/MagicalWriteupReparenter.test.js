import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import MagicalWriteupReparenter from './MagicalWriteupReparenter'

// #4502: the reparenter resolves entirely client-side -- the Page ships only { type, access_denied }
// and the component reads the lookup params off the URL and fetches GET /api/writeup_reparent. These
// tests drive that fetch flow (mount-resolve, repare mapping, re-lookup + pushState, the move POST +
// refresh, gating, errors).

const e2 = (id, title, writeups = []) => ({ node_id: id, title, writeups, is_nodeshell: writeups.length ? 0 : 1 })
const wu = (id, title) => ({ node_id: id, title, author_id: 7, author_title: 'alice', writeuptype: 'idea' })
const okJson = (obj) => ({ ok: true, json: async () => obj })

// GET returns whatever the current test set as `getData`; POST returns `postResult`.
let getData
let postResult
let getCalls

beforeEach(() => {
  getData = { old_e2node: null, old_writeup: null, new_e2node: null, suggested_parent: null, errors: [], kvl_node_id: 1536264 }
  postResult = { success: 1, moved_count: 1, results: [{ success: 1, old_title: 'X (idea)', new_title: 'Y (idea)' }] }
  getCalls = []
  global.fetch = jest.fn((url) => {
    if (String(url).startsWith('/api/writeup_reparent?')) {
      getCalls.push(String(url))
      return Promise.resolve(okJson({ success: 1, data: getData }))
    }
    if (String(url) === '/api/writeup_reparent/reparent') {
      return Promise.resolve(okJson(postResult))
    }
    return Promise.reject(new Error(`unexpected fetch ${url}`))
  })
  jest.spyOn(window.history, 'pushState').mockImplementation(() => {})
})

afterEach(() => {
  jest.restoreAllMocks()
  delete global.fetch
  setSearch('')
})

const origLocation = window.location
const setSearch = (search) =>
  Object.defineProperty(window, 'location', {
    configurable: true,
    writable: true,
    value: { ...origLocation, search, pathname: '/node/741854' }
  })

describe('MagicalWriteupReparenter — gating', () => {
  it('renders the access-denied box and does not fetch when access_denied', () => {
    setSearch('?old_e2node_id=100')
    render(<MagicalWriteupReparenter data={{ type: 'magical_writeup_reparenter', access_denied: 1 }} />)
    expect(screen.getByText(/only available to editors and admins/i)).toBeInTheDocument()
    expect(global.fetch).not.toHaveBeenCalled()
  })

  it('does not fetch on a fresh page (no lookup params in the URL)', async () => {
    setSearch('')
    render(<MagicalWriteupReparenter data={{ type: 'magical_writeup_reparenter' }} />)
    expect(await screen.findByRole('button', { name: /Look Up Nodes/i })).toBeInTheDocument()
    expect(global.fetch).not.toHaveBeenCalled()
  })
})

describe('MagicalWriteupReparenter — mount resolves from the URL', () => {
  it('fetches GET with old_e2node_id and renders the source writeups', async () => {
    setSearch('?old_e2node_id=100')
    getData = { ...getData, old_e2node: e2(100, 'Foo', [wu(201, 'Foo (idea)')]) }
    render(<MagicalWriteupReparenter data={{ type: 'magical_writeup_reparenter' }} />)
    await waitFor(() => expect(getCalls[0]).toContain('old_e2node_id=100'))
    expect(await screen.findByText(/Writeups in/i)).toBeInTheDocument()
    // no destination yet -> no Move button
    expect(screen.queryByRole('button', { name: /Move Selected Writeups/i })).toBeNull()
  })

  it('maps ?repare to the source (old_e2node_id) and seeds the source input', async () => {
    setSearch('?repare=100')
    getData = { ...getData, old_e2node: e2(100, 'Foo', []) }
    const { container } = render(<MagicalWriteupReparenter data={{ type: 'magical_writeup_reparenter' }} />)
    await waitFor(() => expect(getCalls[0]).toContain('old_e2node_id=100'))
    expect(container.querySelector('[placeholder="Enter e2node ID or title"]').value).toBe('100')
  })

  it('shows the Move button once both source and destination resolve', async () => {
    setSearch('?old_e2node_id=100&new_e2node_id=500')
    getData = { ...getData, old_e2node: e2(100, 'Foo', [wu(201, 'w')]), new_e2node: e2(500, 'Bar', []) }
    render(<MagicalWriteupReparenter data={{ type: 'magical_writeup_reparenter' }} />)
    expect(await screen.findByRole('button', { name: /Move Selected Writeups/i })).toBeInTheDocument()
  })

  it('surfaces a lookup error from the API', async () => {
    setSearch('?old_e2node_id=999999')
    getData = { ...getData, errors: ['Invalid old e2node ID or title'] }
    render(<MagicalWriteupReparenter data={{ type: 'magical_writeup_reparenter' }} />)
    expect(await screen.findByText(/Invalid old e2node ID or title/i)).toBeInTheDocument()
  })
})

describe('MagicalWriteupReparenter — Look Up re-fetches without reloading', () => {
  it('fetches the API GET with the form values and pushState-updates the URL', async () => {
    setSearch('') // fresh page, no mount fetch
    render(<MagicalWriteupReparenter data={{ type: 'magical_writeup_reparenter' }} />)
    fireEvent.change(screen.getByPlaceholderText('Enter e2node ID or title'), { target: { value: '100' } })
    fireEvent.change(screen.getByPlaceholderText('Enter destination e2node ID or title'), { target: { value: '500' } })
    fireEvent.click(screen.getByRole('button', { name: /Look Up Nodes/i }))

    await waitFor(() => expect(getCalls.length).toBe(1))
    expect(getCalls[0]).toContain('old_e2node_id=100')
    expect(getCalls[0]).toContain('new_e2node_id=500')
    expect(window.history.pushState).toHaveBeenCalledWith({}, '', expect.stringContaining('old_e2node_id=100'))
  })
})

describe('MagicalWriteupReparenter — reparent (move) via POST', () => {
  it('posts selected writeups, shows feedback, and re-fetches to refresh', async () => {
    setSearch('?old_e2node_id=100&new_e2node_id=500')
    getData = { ...getData, old_e2node: e2(100, 'Foo', [wu(201, 'Foo (idea)')]), new_e2node: e2(500, 'Bar', []) }
    render(<MagicalWriteupReparenter data={{ type: 'magical_writeup_reparenter' }} />)

    // select the source writeup (its checkbox) then move
    const checkbox = await screen.findByRole('checkbox')
    fireEvent.click(checkbox)
    fireEvent.click(screen.getByRole('button', { name: /Move Selected Writeups/i }))

    await waitFor(() =>
      expect(global.fetch).toHaveBeenCalledWith('/api/writeup_reparent/reparent', expect.objectContaining({ method: 'POST' }))
    )
    await screen.findByText(/Successfully moved 1 writeup/i)
    // after a successful move it re-resolves: at least one mount GET + one refresh GET
    await waitFor(() => expect(getCalls.length).toBeGreaterThanOrEqual(2))
  })

  it('refuses to move with no writeups selected', async () => {
    setSearch('?old_e2node_id=100&new_e2node_id=500')
    getData = { ...getData, old_e2node: e2(100, 'Foo', [wu(201, 'w')]), new_e2node: e2(500, 'Bar', []) }
    render(<MagicalWriteupReparenter data={{ type: 'magical_writeup_reparenter' }} />)
    fireEvent.click(await screen.findByRole('button', { name: /Move Selected Writeups/i }))
    expect(await screen.findByText(/select at least one writeup/i)).toBeInTheDocument()
  })
})
