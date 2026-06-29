import React from 'react'
import { render, fireEvent, waitFor } from '@testing-library/react'
import SimpleUsergroupEditor from './SimpleUsergroupEditor'
import fixture from '../../__fixtures__/pagestate/simple_usergroup_editor.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('SimpleUsergroupEditor (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<SimpleUsergroupEditor data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<SimpleUsergroupEditor data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// #4412: add/remove drive the usergroups API (lookup -> adduser/removeuser)
// instead of a POST form that mutated membership in the page controller.
describe('SimpleUsergroupEditor — add/remove via usergroups API (#4412)', () => {
  const data = {
    usergroups: [{ node_id: 100, title: 'Test Group' }],
    selected_usergroup: { node_id: 100, title: 'Test Group' },
    members: [{ node_id: 5, title: 'alice' }, { node_id: 6, title: 'bob' }],
    ignoring_users: [],
  }

  it('resolves usernames, calls removeuser/adduser, and updates the list + message', async () => {
    global.fetch = jest.fn((url) => {
      if (url.includes('/api/nodes/lookup/user/carol')) return Promise.resolve({ ok: true, json: async () => ({ node_id: 9, title: 'carol' }) })
      if (url.includes('/action/removeuser')) return Promise.resolve({ ok: true, json: async () => ({ group: {} }) })
      if (url.includes('/action/adduser')) return Promise.resolve({ ok: true, json: async () => ({ group: {} }) })
      return Promise.resolve({ ok: false, status: 404, json: async () => ({}) })
    })
    try {
      const { getAllByRole, getByRole, getByText, queryByText } = render(<SimpleUsergroupEditor data={data} />)
      fireEvent.click(getAllByRole('checkbox')[1]) // bob (node 6)
      fireEvent.change(getByRole('textbox'), { target: { value: 'carol' } })
      fireEvent.click(getByRole('button', { name: /update group/i }))

      await waitFor(() => expect(getByText(/Added: carol/)).toBeInTheDocument())
      const calls = global.fetch.mock.calls
      const rm = calls.find((c) => c[0].includes('/api/usergroups/100/action/removeuser'))
      const ad = calls.find((c) => c[0].includes('/api/usergroups/100/action/adduser'))
      expect(calls.some((c) => c[0].includes('/api/nodes/lookup/user/carol'))).toBe(true)
      expect(JSON.parse(rm[1].body)).toEqual([6])   // removed bob
      expect(JSON.parse(ad[1].body)).toEqual([9])   // added carol
      // optimistic list update: bob gone, carol present
      expect(getByText('carol')).toBeInTheDocument()
      expect(queryByText('bob')).toBeNull()
      expect(getByText(/Removed: bob/)).toBeInTheDocument()
    } finally { delete global.fetch }
  })

  it('reports not-found usernames (lookup 404) without throwing', async () => {
    global.fetch = jest.fn(() => Promise.resolve({ ok: false, status: 404, json: async () => ({}) }))
    try {
      const { getByRole, getByText } = render(<SimpleUsergroupEditor data={data} />)
      fireEvent.change(getByRole('textbox'), { target: { value: 'ghostuser' } })
      fireEvent.click(getByRole('button', { name: /update group/i }))
      await waitFor(() => expect(getByText(/Not found: ghostuser/)).toBeInTheDocument())
    } finally { delete global.fetch }
  })
})
