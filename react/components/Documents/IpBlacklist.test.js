import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import IpBlacklist from './IpBlacklist'
import fixture from '../../__fixtures__/pagestate/ip_blacklist.json'
import massFixture from '../../__fixtures__/pagestate/mass_ip_blacklister.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('IpBlacklist (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<IpBlacklist data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<IpBlacklist data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
  // #4464: the unified component now also renders the mass_ip_blacklister Document.
  it('also mounts the mass_ip_blacklister fixture (unified component)', () => {
    const { container } = render(<IpBlacklist data={massFixture.contentData} />)
    expect(container).toBeTruthy()
  })
})

// Interaction coverage (#4464): add/remove/paginate moved to POST /api/ip_blacklist/*,
// one unified interface. The `source` selects the audit event server-side.
describe('IpBlacklist interaction (#4464)', () => {
  afterEach(() => {
    jest.restoreAllMocks()
    delete global.fetch
  })

  const baseData = {
    type: 'ip_blacklist',
    source: 'ip_blacklist',
    guest_user_id: 979,
    entries: [{ id: 10, ip_address: '203.0.113.5', comment: 'spam', timestamp: '2026-07-04' }],
    total_count: 1,
    offset: 0,
    page_size: 200,
  }

  it('adds entries (posting source) and renders per-line results + refreshed list', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        success: 1,
        results: [{ ip: '203.0.113.9', success: 1, message: 'The IP "203.0.113.9" was successfully added to the blacklist.' }],
        entries: [
          { id: 11, ip_address: '203.0.113.9', comment: 'spam2', timestamp: 'x' },
          { id: 10, ip_address: '203.0.113.5', comment: 'spam', timestamp: 'y' },
        ],
        total_count: 2,
        offset: 0,
        page_size: 200,
      }),
    })
    render(<IpBlacklist data={baseData} />)
    fireEvent.change(screen.getByPlaceholderText(/one per line/i), { target: { value: '203.0.113.9' } })
    fireEvent.change(screen.getByPlaceholderText(/reason for blocking/i), { target: { value: 'more spam' } })
    fireEvent.click(screen.getByRole('button', { name: /please blacklist/i }))

    await waitFor(() =>
      expect(global.fetch).toHaveBeenCalledWith('/api/ip_blacklist/add', expect.objectContaining({ method: 'POST' }))
    )
    const body = JSON.parse(global.fetch.mock.calls[0][1].body)
    expect(body).toMatchObject({ source: 'ip_blacklist', ips: '203.0.113.9', reason: 'more spam' })
    await waitFor(() => expect(screen.getByText(/successfully added/i)).toBeInTheDocument())
    expect(screen.getByText('203.0.113.9')).toBeInTheDocument()
  })

  it('removes an entry and refreshes the list in place', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        success: 1,
        message: 'The IP "203.0.113.5" was successfully removed from the blacklist.',
        entries: [],
        total_count: 0,
        offset: 0,
        page_size: 200,
      }),
    })
    render(<IpBlacklist data={baseData} />)
    fireEvent.click(screen.getByRole('button', { name: /^remove$/i }))
    await waitFor(() =>
      expect(global.fetch).toHaveBeenCalledWith('/api/ip_blacklist/remove', expect.objectContaining({ method: 'POST' }))
    )
    expect(JSON.parse(global.fetch.mock.calls[0][1].body)).toMatchObject({ id: 10, source: 'ip_blacklist' })
    await waitFor(() => expect(screen.getByText(/No blacklisted IPs found/i)).toBeInTheDocument())
  })

  it('paginates via the list endpoint', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ success: 1, entries: [{ id: 5, ip_address: '203.0.113.1', comment: 'x', timestamp: 'z' }], total_count: 400, offset: 200, page_size: 200 }),
    })
    render(<IpBlacklist data={{ ...baseData, total_count: 400 }} />)
    fireEvent.click(screen.getByRole('button', { name: /Next 200/i }))
    await waitFor(() =>
      expect(global.fetch).toHaveBeenCalledWith('/api/ip_blacklist/list', expect.objectContaining({ method: 'POST' }))
    )
    expect(JSON.parse(global.fetch.mock.calls[0][1].body)).toMatchObject({ offset: 200 })
  })

  it('renders the admin-only error with no form', () => {
    render(<IpBlacklist data={{ type: 'ip_blacklist', error: 'Access denied. This tool is restricted to administrators.' }} />)
    expect(screen.getByText(/restricted to administrators/i)).toBeInTheDocument()
    expect(screen.queryByRole('button')).toBeNull()
  })
})
