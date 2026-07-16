import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import UsergroupMessageArchive from './UsergroupMessageArchive'

// #4541: fetch-driven. GET /api/usergroup_message_archive (list) on mount; group picker + pagination
// refetch in place. Copy-to-inbox still POSTs to /copy (#4472).

const setLocation = (href) => {
  const u = new URL(href)
  window.location.href = href
  window.location.pathname = u.pathname
  window.location.search = u.search
}
const listFetch = (payload) => jest.fn(() => Promise.resolve({ json: () => Promise.resolve(payload) }))

beforeEach(() => { setLocation('http://localhost/?node_id=999'); window.e2 = { node_id: 999 } })
afterEach(() => { delete global.fetch; delete window.e2; jest.restoreAllMocks() })

describe('UsergroupMessageArchive — fetch + picker (#4541)', () => {
  it('shows the guest login message', async () => {
    global.fetch = listFetch({ success: 0, state: 'guest' })
    const { container } = render(<UsergroupMessageArchive user={{ guest: true }} />)
    await waitFor(() => expect(container.textContent).toContain('You must login to use this feature.'))
  })

  it('shows the archive-manager admin link when user.admin', async () => {
    global.fetch = listFetch({ success: 1, archive_groups: [{ node_id: 100, title: 'edev' }] })
    const { container } = render(<UsergroupMessageArchive user={{ admin: true }} />)
    await waitFor(() => expect(container.textContent).toContain('To view messages sent to a group'))
    expect(container.textContent).toContain('usergroup message archive manager')
  })

  it('hides the archive-manager admin link when not admin', async () => {
    global.fetch = listFetch({ success: 1, archive_groups: [{ node_id: 100, title: 'edev' }] })
    const { container } = render(<UsergroupMessageArchive user={{ admin: false }} />)
    await waitFor(() => expect(container.textContent).toContain('To view messages sent to a group'))
    expect(container.textContent).not.toContain('usergroup message archive manager')
  })

  it('renders the error copy for the no_such_group state', async () => {
    setLocation('http://localhost/?node_id=999&viewgroup=nope')
    global.fetch = listFetch({ success: 0, state: 'no_such_group', archive_groups: [] })
    const { container } = render(<UsergroupMessageArchive user={{}} />)
    await waitFor(() => expect(container.textContent).toMatch(/no such usergroup/i))
  })

  it('picks a group in place: refetches with viewgroup, pushes URL, no reload', async () => {
    const pushSpy = jest.spyOn(window.history, 'pushState').mockImplementation(() => {})
    global.fetch = listFetch({ success: 1, archive_groups: [{ node_id: 100, title: 'edev' }] })
    const { getByText } = render(<UsergroupMessageArchive user={{}} />)
    await waitFor(() => expect(getByText('edev')).toBeInTheDocument())

    fireEvent.click(getByText('edev'))
    await waitFor(() => expect(global.fetch.mock.calls.length).toBe(2))
    expect(window.location.href).toBe('http://localhost/?node_id=999') // no reload
    expect(global.fetch.mock.calls[1][0]).toContain('viewgroup=edev')
    expect(pushSpy.mock.calls[pushSpy.mock.calls.length - 1][2]).toContain('viewgroup=edev')
  })
})

// Copy-to-inbox POST to /copy (#4472), now after the mount list-fetch.
describe('UsergroupMessageArchive — copy interaction (#4472)', () => {
  const viewData = {
    success: 1,
    archive_groups: [{ node_id: 999, title: 'edev' }],
    selected_group: { node_id: 999, title: 'edev' },
    messages: [
      { message_id: 11, number: 1, author_id: 5, author_title: 'alice', timestamp: '2026-07-01', text: 'hi' },
      { message_id: 12, number: 2, author_id: 6, author_title: 'bob', timestamp: '2026-07-02', text: 'yo' }
    ],
    total_messages: 2, show_start: 0, max_show: 25, num_show: 2, reset_time: false
  }

  // Mount GET returns the view; POST returns the copy result.
  const mockBoth = (copyResult) => jest.fn((url, opts) =>
    (opts && opts.method === 'POST')
      ? Promise.resolve({ ok: true, json: async () => copyResult })
      : Promise.resolve({ json: async () => viewData })
  )

  beforeEach(() => setLocation('http://localhost/?node_id=999&viewgroup=edev'))

  it('copies selected messages via the API and reports the count', async () => {
    global.fetch = mockBoth({ success: 1, copied_count: 1, reset_time: 0 })
    render(<UsergroupMessageArchive user={{}} />)
    await waitFor(() => expect(screen.getByRole('button', { name: /copy selected messages/i })).toBeInTheDocument())

    fireEvent.click(screen.getAllByRole('checkbox')[1]) // message 11 (checkbox[0] is reset-time)
    fireEvent.click(screen.getByRole('button', { name: /copy selected messages/i }))
    await waitFor(() =>
      expect(global.fetch).toHaveBeenCalledWith('/api/usergroup_message_archive/copy', expect.objectContaining({ method: 'POST' }))
    )
    const postCall = global.fetch.mock.calls.find((c) => c[1] && c[1].method === 'POST')
    expect(JSON.parse(postCall[1].body)).toMatchObject({ group: 'edev', message_ids: [11], reset_time: 0 })
    await waitFor(() => expect(screen.getByText(/Copied 1 group message to self/i)).toBeInTheDocument())
  })

  it('shows an error banner when the copy API rejects', async () => {
    global.fetch = mockBoth({ success: 0, error: "This group doesn't archive messages." })
    render(<UsergroupMessageArchive user={{}} />)
    await waitFor(() => expect(screen.getByRole('button', { name: /copy selected messages/i })).toBeInTheDocument())
    fireEvent.click(screen.getByRole('button', { name: /copy selected messages/i }))
    await waitFor(() => expect(screen.getByText(/doesn't archive messages/i)).toBeInTheDocument())
  })
})
