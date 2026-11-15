import React from 'react'
import { render, screen } from '@testing-library/react'
import AYearAgoToday from './AYearAgoToday'
import fixture from '../../__fixtures__/pagestate/a_year_ago_today.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
// AYearAgoToday renders LinkNode, but LinkNode is a plain anchor helper (no react-router),
// so no router provider is needed.
describe('AYearAgoToday (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<AYearAgoToday data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<AYearAgoToday data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// The captured fixture above has nodes: [] -- so none of those tests ever rendered a writeup row
// (#4579). These feed real rows in the shape Application::previous_years_entry now emits.
describe('AYearAgoToday with writeup rows (#4579)', () => {
  const row = (over = {}) => ({
    node_id: 501,
    createtime: '2025-11-15T23:30:00Z', // late UTC: a local-time formatter would roll this to the 16th east of UTC
    parent: { node_id: 500, title: 'Iron Noder 2025' },
    author: { node_id: 113, title: 'root' },
    ...over,
  })
  const page = (over = {}) => ({ current_year: 2026, count: 1, yearsago: 1, startat: 0, nodes: [row()], ...over })

  it('renders a row: parent title, author, and the date in UTC', () => {
    render(<AYearAgoToday data={page()} />)
    expect(screen.getByText('Iron Noder 2025')).toBeInTheDocument()
    expect(screen.getByText('root')).toBeInTheDocument()
    expect(screen.getByText(/entered on Nov 15, 2025/)).toBeInTheDocument()
  })

  it('tolerates a missing parent and author (server sends null)', () => {
    render(<AYearAgoToday data={page({ nodes: [row({ parent: null, author: null })] })} />)
    expect(screen.getByText('(untitled)')).toBeInTheDocument()
    expect(screen.getByText(/by\s+unknown/)).toBeInTheDocument()
    expect(screen.queryByText('full')).toBeNull()
  })

  // Where a link actually goes once the browser resolves it (LinkNode's raw href keeps a literal space).
  const PAGE = '/title/A%20Year%20Ago%20Today'
  const dest = (a) => { const u = new URL(a.href); return u.origin + u.pathname + u.search }

  it('pagination does arithmetic, not string concatenation', () => {
    const { container } = render(<AYearAgoToday data={page({ count: 200, startat: 50 })} />)
    const hrefs = [...container.querySelectorAll('.year-ago-today__pagination a')].map(dest)
    expect(hrefs).toContain(`http://localhost${PAGE}?yearsago=1&startat=100`) // was startat=5050 with string startat
    expect(hrefs).toContain(`http://localhost${PAGE}?yearsago=1`)             // prev to the first page drops startat=0
  })

  it('under prod\'s guest <base href>, year and page links still resolve to this page, not the homepage', () => {
    // Prod emits this for guests; the old bare "?yearsago=2" hrefs resolved against it -> the homepage.
    const base = document.createElement('base')
    base.href = 'https://everything2.com'
    document.head.appendChild(base)
    try {
      const { container } = render(<AYearAgoToday data={page({ count: 200, startat: 50 })} />)
      const links = [...container.querySelectorAll('.year-ago-today__pagination a, .year-ago-today__years a')]
      expect(links.length).toBeGreaterThan(5)
      links.forEach((a) => {
        expect(a.getAttribute('href').startsWith('?')).toBe(false)
        expect(dest(a).startsWith(`https://everything2.com${PAGE}?yearsago=`)).toBe(true)
      })
      const y2024 = links.find((a) => a.textContent === '2024')
      expect(dest(y2024)).toBe(`https://everything2.com${PAGE}?yearsago=2`) // a year jump drops startat
    } finally {
      base.remove()
    }
  })

  it('wording and year highlight follow yearsago', () => {
    const { container, rerender } = render(<AYearAgoToday data={page({ yearsago: 1 })} />)
    expect(screen.getByText(/writeups submitted a year ago today/)).toBeInTheDocument()
    rerender(<AYearAgoToday data={page({ yearsago: 2 })} />)
    expect(screen.getByText(/writeups submitted 2 years ago today/)).toBeInTheDocument()
    expect(container.querySelector('.year-ago-today__years strong').textContent).toBe('2024')
  })
})
