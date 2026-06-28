import React from 'react'
import { render } from '@testing-library/react'
import UsergroupMessageArchive from './UsergroupMessageArchive'
import fixture from '../../__fixtures__/pagestate/usergroup_message_archive.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('UsergroupMessageArchive (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<UsergroupMessageArchive data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<UsergroupMessageArchive data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// Role gating now reads from the global e2.user prop (#4390 contentData dedup),
// not duplicated is_admin/is_guest keys in contentData.
describe('UsergroupMessageArchive role gating via user prop', () => {
  const memberData = {
    type: 'usergroup_message_archive',
    archive_groups: [],
    node_id: 12345
  }

  it('shows guest login message when user.guest, regardless of contentData', () => {
    const { container } = render(
      <UsergroupMessageArchive
        data={{ type: 'usergroup_message_archive', message: 'You must login to use this feature.' }}
        user={{ guest: true, admin: false }}
      />
    )
    expect(container.textContent).toContain('You must login to use this feature.')
  })

  it('shows the archive-manager admin link when user.admin', () => {
    const { container } = render(
      <UsergroupMessageArchive data={memberData} user={{ guest: false, admin: true }} />
    )
    expect(container.textContent).toContain('usergroup message archive manager')
  })

  it('hides the archive-manager admin link when not admin', () => {
    const { container } = render(
      <UsergroupMessageArchive data={memberData} user={{ guest: false, admin: false }} />
    )
    expect(container.textContent).not.toContain('usergroup message archive manager')
  })

  it('does not crash and renders as non-admin/non-guest when user is undefined', () => {
    const { container } = render(<UsergroupMessageArchive data={memberData} user={undefined} />)
    expect(container.textContent).toContain('To view messages sent to a group')
    expect(container.textContent).not.toContain('usergroup message archive manager')
  })
})

// The current page node_id now comes from the global e2.node prop (#4399 contentData
// node-id dedup), not a duplicated node_id key in contentData.
describe('UsergroupMessageArchive page node_id via e2 prop', () => {
  const archiveGroups = [{ node_id: 999, title: 'Test Group' }]

  it('builds archive-group links from e2.node.node_id, not contentData', () => {
    const { container } = render(
      <UsergroupMessageArchive
        data={{ type: 'usergroup_message_archive', archive_groups: archiveGroups }}
        e2={{ node: { node_id: 424242 } }}
        user={{ guest: false, admin: false }}
      />
    )
    const link = container.querySelector('a.usergroup-archive__link')
    expect(link.getAttribute('href')).toContain('node_id=424242')
    // The referenced usergroup link text is still rendered from its own node.
    expect(container.textContent).toContain('Test Group')
  })
})
