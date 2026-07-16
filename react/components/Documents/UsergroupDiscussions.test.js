import React from 'react'
import { render, waitFor, fireEvent } from '@testing-library/react'
import UsergroupDiscussions from './UsergroupDiscussions'

// #4541: fetch-driven. GET /api/usergroup_discussions on mount; usergroup selector + pagination
// refetch in place via history.pushState. Guest/no_usergroups/access_denied copy owned by React.

const setLocation = (href) => {
  const u = new URL(href)
  window.location.href = href
  window.location.pathname = u.pathname
  window.location.search = u.search
}
const mockFetch = (payload) => jest.fn(() => Promise.resolve({ json: () => Promise.resolve(payload) }))
const usergroups = [{ node_id: 100, title: 'edev' }, { node_id: 200, title: 'gods' }]
const discussion = { node_id: 42, title: 'A Discussion', author_id: 7, author_title: 'alice', usergroup_id: 100, usergroup_title: 'edev', reply_count: 3, unread: true, last_updated: '2026-01-01' }

beforeEach(() => { setLocation('http://localhost/?node_id=500'); window.e2 = { node_id: 500 } })
afterEach(() => { delete global.fetch; delete window.e2; jest.restoreAllMocks() })

describe('UsergroupDiscussions — fetch + states (#4541)', () => {
  it('renders the guest copy when the API refuses', async () => {
    global.fetch = mockFetch({ success: 0, state: 'guest' })
    const { container } = render(<UsergroupDiscussions user={{ guest: true }} />)
    await waitFor(() => expect(container.textContent).toMatch(/long-winded conversations/i))
  })

  it('renders the no_usergroups copy', async () => {
    global.fetch = mockFetch({ success: 0, state: 'no_usergroups' })
    const { container } = render(<UsergroupDiscussions user={{}} />)
    await waitFor(() => expect(container.textContent).toMatch(/You have no usergroups/i))
  })

  it('renders access_denied with the selector still shown', async () => {
    setLocation('http://localhost/?node_id=500&show_ug=999')
    global.fetch = mockFetch({ success: 0, state: 'access_denied', usergroups, selected_usergroup: 999 })
    const { container } = render(<UsergroupDiscussions user={{}} />)
    await waitFor(() => expect(container.textContent).toMatch(/not a member of the selected usergroup/i))
    expect(container.querySelector('.ug-discussions__selector')).toBeTruthy()
  })

  it('renders the discussions table for a member', async () => {
    global.fetch = mockFetch({ success: 1, usergroups, selected_usergroup: 0, discussions: [discussion], total_discussions: 1, offset: 0, limit: 50 })
    const { container } = render(<UsergroupDiscussions user={{}} />)
    await waitFor(() => expect(container.querySelector('.ug-discussions__table')).toBeTruthy())
    expect(container.textContent).toMatch(/A Discussion/)
    expect(container.textContent).toMatch(/alice/)
    expect(container.textContent).toMatch(/There are 1 discussions total/)
    // unread boolean renders the × marker
    expect(container.textContent).toContain('×')
  })
})

describe('UsergroupDiscussions — in-place selector/pagination (#4541, no reload)', () => {
  it('selecting a usergroup refetches with show_ug and pushes URL, no reload', async () => {
    const pushSpy = jest.spyOn(window.history, 'pushState').mockImplementation(() => {})
    global.fetch = mockFetch({ success: 1, usergroups, selected_usergroup: 0, discussions: [], total_discussions: 0, offset: 0, limit: 50 })
    const { container } = render(<UsergroupDiscussions user={{}} />)
    await waitFor(() => expect(container.querySelector('.ug-discussions__usergroup-link')).toBeTruthy())

    // the first selector link is edev (node_id 100); "edev" also appears as a form <option>
    fireEvent.click(container.querySelector('.ug-discussions__usergroup-link'))
    await waitFor(() => expect(global.fetch.mock.calls.length).toBe(2))
    expect(window.location.href).toBe('http://localhost/?node_id=500') // no hard navigation
    expect(global.fetch.mock.calls[1][0]).toContain('show_ug=100')
    expect(pushSpy.mock.calls[pushSpy.mock.calls.length - 1][2]).toContain('show_ug=100')
  })

  it('paginates in place', async () => {
    const pushSpy = jest.spyOn(window.history, 'pushState').mockImplementation(() => {})
    // 60 total, 50 shown -> a "next" link
    global.fetch = mockFetch({ success: 1, usergroups, selected_usergroup: 0, discussions: [discussion], total_discussions: 60, offset: 0, limit: 50 })
    const { getByText } = render(<UsergroupDiscussions user={{}} />)
    await waitFor(() => expect(getByText(/next/i)).toBeInTheDocument())

    fireEvent.click(getByText(/next/i))
    await waitFor(() => expect(global.fetch.mock.calls.length).toBe(2))
    expect(global.fetch.mock.calls[1][0]).toContain('offset=50')
  })
})
