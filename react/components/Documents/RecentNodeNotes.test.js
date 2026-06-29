import React from 'react'
import { render, fireEvent } from '@testing-library/react'
import RecentNodeNotes from './RecentNodeNotes'
import fixture from '../../__fixtures__/pagestate/recent_node_notes.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('RecentNodeNotes (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<RecentNodeNotes data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<RecentNodeNotes data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// #4389: restore noter attribution, badge auto-generated lifecycle breadcrumbs,
// default the "hide automated notes" filter on, and format timestamps as UTC.
describe('RecentNodeNotes — author + lifecycle badge (#4389)', () => {
  const baseData = (overrides = {}) => ({
    notes: [], total: 0, page: 0, perpage: 50,
    onlymynotes: 0, hidesystemnotes: 1, node: null, ...overrides,
  })

  it('relabels the filter "Hide automated notes" and checks it by default', () => {
    const { getByLabelText } = render(<RecentNodeNotes data={baseData()} />)
    expect(getByLabelText(/hide automated notes/i)).toBeChecked()
  })

  it('shows the noter as attribution and badges only the auto note', () => {
    const data = baseData({
      total: 2,
      notes: [
        { node: { node_id: 10, title: 'Apple' }, timestamp: '2026-06-20 12:00:00', note: 'Published from draft', noter: 'Glowing Fish', kind: 'auto' },
        { node: { node_id: 11, title: 'Banana' }, timestamp: '2026-06-20 13:00:00', note: 'Add sources please', noter: 'editorperson', kind: 'editorial' },
      ],
    })
    const { getByText, container } = render(<RecentNodeNotes data={data} />)
    expect(getByText('Glowing Fish')).toBeInTheDocument()
    expect(getByText('editorperson')).toBeInTheDocument()
    expect(container.querySelectorAll('.recent-node-notes__badge')).toHaveLength(1)
  })

  it('formats the timestamp via the UTC date util (no "Invalid Date")', () => {
    const data = baseData({
      total: 1,
      notes: [{ node: { node_id: 10, title: 'Apple' }, timestamp: '2026-06-20 12:00:00', note: 'x', noter: 'someone', kind: 'editorial' }],
    })
    const { container } = render(<RecentNodeNotes data={data} />)
    const ts = container.querySelector('.recent-node-notes__timestamp').textContent
    expect(ts).not.toMatch(/invalid date/i)
    expect(ts).toMatch(/2026/)
  })

  it('does not badge or attribute a bare system note (no noter, editorial kind absent)', () => {
    const data = baseData({
      total: 1,
      notes: [{ node: { node_id: 10, title: 'Apple' }, timestamp: '2026-06-20 12:00:00', note: 'legacy note', kind: 'auto' }],
    })
    const { container } = render(<RecentNodeNotes data={data} />)
    // auto badge present, but no noter prefix span when noter is undefined
    expect(container.querySelectorAll('.recent-node-notes__badge')).toHaveLength(1)
    expect(container.querySelector('.recent-node-notes__noter')).toBeNull()
  })
})

// #4389: toggling a filter reloads the CURRENT page. A superdoc's identity lives
// in the query string (/index.pl?node=...&type=superdoc); rebuilding the URL from
// pathname alone dropped it and bounced to the homepage. Guard the preservation.
describe('RecentNodeNotes — filter navigation preserves the page (#4389 homepage bounce)', () => {
  const navData = (overrides = {}) => ({
    notes: [], total: 0, page: 0, perpage: 50,
    onlymynotes: 0, hidesystemnotes: 1, node: null, ...overrides,
  })

  const withLocation = (href, fn) => {
    const saved = window.location
    const u = new URL(href)
    delete window.location
    window.location = { href, pathname: u.pathname, search: u.search }
    try { fn() } finally { window.location = saved }
  }

  it('keeps a superdoc query-string identity when toggling a filter (no homepage bounce)', () => {
    withLocation('http://localhost/index.pl?node=Recent+Node+Notes&type=superdoc', () => {
      const { getByLabelText } = render(<RecentNodeNotes data={navData()} />)
      fireEvent.click(getByLabelText(/hide automated notes/i)) // checked -> unchecked
      const dest = window.location.href
      expect(dest).toContain('node=Recent')       // node identity preserved
      expect(dest).toContain('type=superdoc')     // type preserved
      expect(dest).toContain('hidesystemnotes=0') // filter applied
      expect(dest.startsWith('/index.pl')).toBe(true) // stayed on the page, not '/'
    })
  })

  it('keeps a /node/<id> path identity when toggling a filter', () => {
    withLocation('http://localhost/node/1429619', () => {
      const { getByLabelText } = render(<RecentNodeNotes data={navData()} />)
      fireEvent.click(getByLabelText(/show only my notes/i))
      const dest = window.location.href
      expect(dest.startsWith('/node/1429619')).toBe(true)
      expect(dest).toContain('onlymynotes=1')
    })
  })
})
