import React from 'react'
import { render, fireEvent, waitFor } from '@testing-library/react'
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

// #4509: the Page ships only { type }; this component owns the flavor text + permission tier,
// keyed on the type via TOOL_CONFIG.
describe('AdminBestowTool config-map path (Page ships just { type })', () => {
  const origLocation = window.location
  beforeEach(() =>
    Object.defineProperty(window, 'location', { configurable: true, writable: true, value: { search: '', origin: '' } })
  )
  afterEach(() => {
    Object.defineProperty(window, 'location', { configurable: true, writable: true, value: origLocation })
    delete global.fetch
    jest.restoreAllMocks()
  })
  const firstUser = (c) => c.querySelector('input[placeholder="Enter username"]').value

  it('renders a tool entirely from its type for an admin (bestow_cools)', () => {
    const { container } = render(<AdminBestowTool data={{ type: 'bestow_cools' }} user={{ admin: true }} />)
    expect(container.textContent).toMatch(/Grant cools/)          // description
    expect(container.textContent).toMatch(/Bestow Cools/)         // button
    expect(container.querySelector('form')).toBeTruthy()
    expect(container.querySelector('.admin-bestow__permission-error')).toBeNull()
  })

  it('gates an admin tool: a non-admin sees only the permission error, no form', () => {
    const { container } = render(<AdminBestowTool data={{ type: 'bestow_cools' }} user={{ admin: false }} />)
    expect(container.textContent).toMatch(/Only administrators can bestow cools/)
    expect(container.querySelector('form')).toBeNull()
  })

  it('editor-tier tool (superbless): editors pass, plain users are blocked, admins pass (admins are editors)', () => {
    const editor = render(<AdminBestowTool data={{ type: 'superbless' }} user={{ editor: true }} />)
    expect(editor.container.querySelector('form')).toBeTruthy()

    const plain = render(<AdminBestowTool data={{ type: 'superbless' }} user={{ admin: false, editor: false }} />)
    expect(plain.container.querySelector('form')).toBeNull()
    expect(plain.container.textContent).toMatch(/available to editors and administrators/)

    const admin = render(<AdminBestowTool data={{ type: 'superbless' }} user={{ admin: true, editor: false }} />)
    expect(admin.container.querySelector('form')).toBeTruthy()
  })

  it('teddy intro names the acting user', () => {
    const { container } = render(<AdminBestowTool data={{ type: 'giant_teddy_bear_suit' }} user={{ admin: true, title: 'root' }} />)
    expect(container.textContent).toMatch(/root has donned the Giant Teddy Bear Suit/)
  })

  it('the_well_of_cool is self-service: any user, row 0 prefilled with themselves', () => {
    const { container } = render(<AdminBestowTool data={{ type: 'the_well_of_cool' }} user={{ title: 'normaluser1' }} />)
    expect(container.querySelector('form')).toBeTruthy() // requires: none -> everyone
    expect(firstUser(container)).toBe('normaluser1')
    expect(container.querySelectorAll('input[placeholder="Enter username"]').length).toBe(1) // row_count 1
  })

  it('submits to the tool\'s own API endpoint (bestow_cools -> grant_cools)', async () => {
    global.fetch = jest.fn(() => Promise.resolve({ ok: true, json: () => Promise.resolve({ results: [] }) }))
    const { container } = render(<AdminBestowTool data={{ type: 'bestow_cools' }} user={{ admin: true }} />)
    const input = container.querySelector('input[placeholder="Enter username"]')
    fireEvent.change(input, { target: { value: 'normaluser1' } })
    fireEvent.submit(container.querySelector('form'))
    await waitFor(() => expect(global.fetch).toHaveBeenCalled())
    expect(global.fetch.mock.calls[0][0]).toBe('/api/superbless/grant_cools')
  })
})
