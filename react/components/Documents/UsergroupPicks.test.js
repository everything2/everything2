import React from 'react'
import { render } from '@testing-library/react'
import UsergroupPicks from './UsergroupPicks'
import fixture from '../../__fixtures__/pagestate/usergroup_picks.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('UsergroupPicks (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<UsergroupPicks data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<UsergroupPicks data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// Admin gating now reads e2.user.admin (the viewer's role flag), not a
// duplicated contentData.isAdmin key (#4399). The "unlink" affordance only
// renders for admins.
describe('UsergroupPicks admin gating (user.admin)', () => {
  const viewingData = {
    type: 'usergroup_picks',
    groups: [{ node_id: 838015, title: 'edev', count: 1 }],
    viewWeblog: 838015,
    viewGroupName: 'edev',
    entries: [
      { node_id: 111, title: 'Some Writeup', timestamp: '2026-06-09 20:16:43', linker_id: 113, linker_name: 'root' },
    ],
    skippedCount: 0,
  }

  it('shows the unlink affordance when user.admin is true', () => {
    const { container } = render(<UsergroupPicks data={viewingData} user={{ admin: true }} />)
    expect(container.textContent).toMatch(/unlink/i)
  })

  it('hides the unlink affordance when user.admin is false', () => {
    const { container } = render(<UsergroupPicks data={viewingData} user={{ admin: false }} />)
    expect(container.textContent).not.toMatch(/unlink/i)
  })

  it('does not crash and hides admin UI when user is undefined', () => {
    const { container } = render(<UsergroupPicks data={viewingData} user={undefined} />)
    expect(container.textContent).toContain('Some Writeup')
    expect(container.textContent).not.toMatch(/unlink/i)
  })
})
