import React from 'react'
import { render } from '@testing-library/react'
import UsergroupDiscussions from './UsergroupDiscussions'
import fixture from '../../__fixtures__/pagestate/usergroup_discussions.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('UsergroupDiscussions (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<UsergroupDiscussions data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<UsergroupDiscussions data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// #4390: viewer guest flag now comes from the global e2.user prop (user.guest),
// not a duplicated contentData.is_guest key.
describe('UsergroupDiscussions guest gating (#4390 e2.user dedup)', () => {
  // The captured fixture is a guest payload (contentData = type/message only).
  // A logged-in viewer reaches the main branch, which needs the populated arrays.
  const loggedInData = {
    type: 'usergroup_discussions',
    usergroups: [{ node_id: 114, title: 'gods' }],
    selected_usergroup: 0,
    discussions: [],
    total_discussions: 0,
    offset: 0,
    limit: 50,
    node_id: 555
  }

  it('guest viewer (user.guest=true) sees the logged-out message, not the new-discussion form', () => {
    const { container } = render(
      <UsergroupDiscussions data={fixture.contentData} user={{ guest: true }} />
    )
    expect(container.textContent).toContain('you would be able to strike up')
    expect(container.textContent).not.toContain('Start a New Discussion')
  })

  it('logged-in viewer (user.guest=false) sees the new-discussion form, not the guest message', () => {
    const { container } = render(
      <UsergroupDiscussions data={loggedInData} user={{ guest: false }} />
    )
    expect(container.textContent).toContain('Start a New Discussion')
    expect(container.textContent).not.toContain('you would be able to strike up')
  })

  it('missing user prop does not crash and treats viewer as logged-in', () => {
    const { container } = render(
      <UsergroupDiscussions data={loggedInData} user={undefined} />
    )
    expect(container).toBeTruthy()
    expect(container.textContent).toContain('Start a New Discussion')
    expect(container.textContent).not.toContain('you would be able to strike up')
  })
})
