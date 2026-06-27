import React from 'react'
import { render } from '@testing-library/react'
import NewsArchives from './NewsArchives'
import fixture from '../../__fixtures__/pagestate/news_archives.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('NewsArchives (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<NewsArchives data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<NewsArchives data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })

  // Admin gating reads from the global user prop (user.admin), not contentData (#4390).
  const groupData = {
    type: 'news_archives',
    groups: [],
    viewWeblog: 114,
    viewGroupName: 'Editor Picks',
    entries: [{ node_id: 42, title: 'Some Node', timestamp: '2026-01-01 00:00:00', linker_id: 113, linker_name: 'root' }],
    skippedCount: 0,
  }

  it('shows unlink controls for admins (user.admin === true)', () => {
    const { container } = render(<NewsArchives data={groupData} user={{ admin: true }} />)
    expect(container.textContent).toMatch(/Unlink\?/)
    expect(container.textContent).toMatch(/unlink/)
  })

  it('hides unlink controls for non-admins (user.admin === false)', () => {
    const { container } = render(<NewsArchives data={groupData} user={{ admin: false }} />)
    expect(container.textContent).not.toMatch(/Unlink\?/)
  })

  it('does not crash when user is undefined', () => {
    const { container } = render(<NewsArchives data={groupData} user={undefined} />)
    expect(container.textContent).not.toMatch(/Unlink\?/)
    expect(container).toBeTruthy()
  })
})
