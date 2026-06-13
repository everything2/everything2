import React from 'react'
import { render, screen } from '@testing-library/react'
import SecurityMonitor from './SecurityMonitor'
import fixture from '../../__fixtures__/pagestate/security_monitor.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('SecurityMonitor (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<SecurityMonitor data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<SecurityMonitor data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// Phase-4 cutover (#4277): categories are keyed by event id (sectype=id), and
// entries link the seclog_subject (often absent) -- not the old category node.
describe('SecurityMonitor (event-keyed contract)', () => {
  const data = {
    node_id: 42,
    categories: [
      { id: 5, name: 'Kill reasons', group: 'content', count: 3 },
      { id: 1, name: 'User Signup', group: 'accounts', count: 100 },
    ],
    viewing_type: 5,
    entries: [
      { subject_id: 999, subject_title: 'Some Node', user_id: 114, user_title: 'root', time: '2026-06-13 00:00:00', details: 'X removed Y' },
      { subject_id: 0, subject_title: null, user_id: 114, user_title: 'root', time: '2026-06-13 00:01:00', details: 'no subject here' },
    ],
    startat: 0,
    total: 3,
    page_size: 50,
  }

  it('category drill-in uses the event id as sectype', () => {
    const { container } = render(<SecurityMonitor data={data} />)
    expect(screen.getByText('Kill reasons')).toBeTruthy()
    expect(container.querySelector('a[href*="sectype=5"]')).toBeTruthy()
  })

  it('renders the subject node and survives a null subject', () => {
    render(<SecurityMonitor data={data} />)
    expect(screen.getByText('Some Node')).toBeTruthy()       // linked subject
    expect(screen.getByText('X removed Y')).toBeTruthy()      // details
    expect(screen.getByText('no subject here')).toBeTruthy()  // null-subject row still renders
  })
})
