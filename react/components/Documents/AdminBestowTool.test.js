import React from 'react'
import { render } from '@testing-library/react'
import AdminBestowTool from './AdminBestowTool'
import fixture from '../../__fixtures__/pagestate/admin_bestow_tool.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108). This unified component also serves the
// superbless / xp_superbless document types, but the server normalizes all of those to
// contentData.type === 'admin_bestow_tool' (see Everything::Page::superbless), so the
// admin_bestow_tool fixture is the canonical real payload.
describe('AdminBestowTool (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<AdminBestowTool data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<AdminBestowTool data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// Prefill is client-owned (#4500): read off window.location, with a fallback to a server-supplied
// data.prefill_username for AdminBestowTool consumers not yet migrated off the server read.
describe('AdminBestowTool prefill_username', () => {
  const origLocation = window.location
  const setSearch = (search) =>
    Object.defineProperty(window, 'location', { configurable: true, writable: true, value: { search } })
  afterEach(() =>
    Object.defineProperty(window, 'location', { configurable: true, writable: true, value: origLocation })
  )

  const cfg = { type: 'admin_bestow_tool', has_permission: 1, row_count: 3, api_endpoint: '/api/x' }
  const firstUser = (c) => c.querySelector('input[placeholder="Enter username"]').value

  it('prefills the first username from ?prefill_username when the server ships none', () => {
    setSearch('?prefill_username=bob')
    const { container } = render(<AdminBestowTool data={cfg} />)
    expect(firstUser(container)).toBe('bob')
  })

  it('a server-supplied data.prefill_username still wins (unmigrated consumers)', () => {
    setSearch('?prefill_username=bob')
    const { container } = render(<AdminBestowTool data={{ ...cfg, prefill_username: 'alice' }} />)
    expect(firstUser(container)).toBe('alice')
  })

  it('leaves the first username blank when neither URL nor data provide it', () => {
    setSearch('')
    const { container } = render(<AdminBestowTool data={cfg} />)
    expect(firstUser(container)).toBe('')
  })
})
