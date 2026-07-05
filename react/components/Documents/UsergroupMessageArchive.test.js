import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
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

// Copy-to-inbox + reset-time moved to POST /api/usergroup_message_archive/copy (#4472).
describe('UsergroupMessageArchive copy interaction (#4472)', () => {
  afterEach(() => {
    jest.restoreAllMocks()
    delete global.fetch
  })

  const viewData = {
    type: 'usergroup_message_archive',
    archive_groups: [{ node_id: 999, title: 'edev' }],
    selected_group: { node_id: 999, title: 'edev' },
    messages: [
      { message_id: 11, number: 1, author_id: 5, author_title: 'alice', timestamp: '2026-07-01', text: 'hi' },
      { message_id: 12, number: 2, author_id: 6, author_title: 'bob', timestamp: '2026-07-02', text: 'yo' },
    ],
    total_messages: 2,
    show_start: 0,
    max_show: 25,
    num_show: 2,
    reset_time: 0,
  }
  const props = { data: viewData, e2: { node: { node_id: 999 } }, user: { guest: false } }

  it('copies the selected messages via the API and reports the count', async () => {
    global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: 1, copied_count: 1, reset_time: 0 }) })
    render(<UsergroupMessageArchive {...props} />)
    // checkbox[0] is the reset-time toggle; message checkboxes follow in row order.
    fireEvent.click(screen.getAllByRole('checkbox')[1]) // message_id 11
    fireEvent.click(screen.getByRole('button', { name: /copy selected messages/i }))
    await waitFor(() =>
      expect(global.fetch).toHaveBeenCalledWith('/api/usergroup_message_archive/copy', expect.objectContaining({ method: 'POST' }))
    )
    expect(JSON.parse(global.fetch.mock.calls[0][1].body)).toMatchObject({ group: 'edev', message_ids: [11], reset_time: 0 })
    await waitFor(() => expect(screen.getByText(/Copied 1 group message to self/i)).toBeInTheDocument())
  })

  it('sends reset_time when the "keep original date" box is toggled', async () => {
    global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: 1, copied_count: 0, reset_time: 1 }) })
    render(<UsergroupMessageArchive {...props} />)
    fireEvent.click(screen.getAllByRole('checkbox')[0]) // reset-time toggle
    fireEvent.click(screen.getByRole('button', { name: /copy selected messages/i }))
    await waitFor(() => expect(global.fetch).toHaveBeenCalled())
    expect(JSON.parse(global.fetch.mock.calls[0][1].body)).toMatchObject({ reset_time: 1, message_ids: [] })
  })

  it('shows an error banner when the API rejects', async () => {
    global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: 0, error: "This group doesn't archive messages." }) })
    render(<UsergroupMessageArchive {...props} />)
    fireEvent.click(screen.getByRole('button', { name: /copy selected messages/i }))
    await waitFor(() => expect(screen.getByText(/doesn't archive messages/i)).toBeInTheDocument())
  })
})
