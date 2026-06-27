import React from 'react'
import { render } from '@testing-library/react'
import MyBigWriteupList from './MyBigWriteupList'
import fixture from '../../__fixtures__/pagestate/my_big_writeup_list.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('MyBigWriteupList (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<MyBigWriteupList data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<MyBigWriteupList data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

describe('MyBigWriteupList admin role gating (#4390, reads user.admin)', () => {
  // The rendered search form's user-search input ("Search for user:") is admin-only;
  // non-admins instead get a "For: <username>" row. This payload reaches the main render.
  const listData = {
    type: 'my_big_writeup_list',
    username: 'someuser',
    user_id: 42,
    is_me: 0,
    show_rep: 0,
    total_count: 0,
    writeups: []
  }

  it('admin sees the user-search input', () => {
    const { container } = render(
      <MyBigWriteupList data={listData} user={{ admin: true, editor: true }} />
    )
    expect(container.textContent).toContain('Search for user:')
  })

  it('non-admin does not see the user-search input', () => {
    const { container } = render(
      <MyBigWriteupList data={listData} user={{ admin: false, editor: false }} />
    )
    expect(container.textContent).not.toContain('Search for user:')
    expect(container.textContent).toContain('For: someuser')
  })

  it('renders without crashing when user is undefined', () => {
    const { container } = render(<MyBigWriteupList data={listData} user={undefined} />)
    expect(container.textContent).not.toContain('Search for user:')
  })
})
