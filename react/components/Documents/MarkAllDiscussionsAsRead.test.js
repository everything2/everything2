import React from 'react'
import { render, fireEvent, waitFor } from '@testing-library/react'
import MarkAllDiscussionsAsRead from './MarkAllDiscussionsAsRead'
import fixture from '../../__fixtures__/pagestate/mark_all_discussions_as_read.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('MarkAllDiscussionsAsRead (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<MarkAllDiscussionsAsRead data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<MarkAllDiscussionsAsRead data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// Role flags now come from the global e2.user prop, not contentData (#4390 dedup)
describe('MarkAllDiscussionsAsRead (admin gating via user prop)', () => {
  const baseData = { node_id: 123, ce_marked: 0, admin_marked: 0, messages: [] }

  it('shows the admin debates section when user.admin is true', () => {
    const { container } = render(<MarkAllDiscussionsAsRead data={baseData} user={{ admin: true }} />)
    expect(container.textContent).toMatch(/Mark Admin Debates as Read/)
  })

  it('hides the admin debates section for a non-admin editor', () => {
    const { container } = render(<MarkAllDiscussionsAsRead data={baseData} user={{ admin: false, editor: true }} />)
    expect(container.textContent).not.toMatch(/Mark Admin Debates as Read/)
    // CE section still renders for any gated viewer
    expect(container.textContent).toMatch(/Mark CE Debates as Read/)
  })

  it('does not crash and hides admin UI when user is undefined', () => {
    const { container } = render(<MarkAllDiscussionsAsRead data={baseData} user={undefined} />)
    expect(container.textContent).toMatch(/Mark CE Debates as Read/)
    expect(container.textContent).not.toMatch(/Mark Admin Debates as Read/)
  })
})

// #4410: the buttons POST to /api/markdiscussionsread/{ce,admin} (were GET links
// that marked debates read during render) and show the done message client-side.
describe('MarkAllDiscussionsAsRead — mark via API (#4410)', () => {
  it('CE button POSTs to /api/markdiscussionsread/ce and shows the done message', async () => {
    const fetchMock = (global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: 1, count: 5 }) }))
    try {
      const { getByRole, getByText } = render(<MarkAllDiscussionsAsRead data={{}} user={{ editor: true }} />)
      fireEvent.click(getByRole('button', { name: /mark ce debates as read/i }))
      await waitFor(() =>
        expect(fetchMock).toHaveBeenCalledWith('/api/markdiscussionsread/ce', expect.objectContaining({ method: 'POST' }))
      )
      await waitFor(() => expect(getByText(/CE debates have been marked as read \(5 updated\)/i)).toBeInTheDocument())
    } finally { delete global.fetch }
  })

  it('admin button POSTs to /api/markdiscussionsread/admin and shows the done message', async () => {
    const fetchMock = (global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: 1, count: 2 }) }))
    try {
      const { getByRole, getByText } = render(<MarkAllDiscussionsAsRead data={{}} user={{ admin: true }} />)
      fireEvent.click(getByRole('button', { name: /mark admin debates as read/i }))
      await waitFor(() =>
        expect(fetchMock).toHaveBeenCalledWith('/api/markdiscussionsread/admin', expect.objectContaining({ method: 'POST' }))
      )
      await waitFor(() => expect(getByText(/admin debates have been marked as read \(2 updated\)/i)).toBeInTheDocument())
    } finally { delete global.fetch }
  })

  it('shows an error and stays on the button when the API rejects', async () => {
    global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: 0, error: 'Editor or admin access required' }) })
    try {
      const { getByRole, getByText } = render(<MarkAllDiscussionsAsRead data={{}} user={{ editor: true }} />)
      fireEvent.click(getByRole('button', { name: /mark ce debates as read/i }))
      await waitFor(() => expect(getByText(/editor or admin access required/i)).toBeInTheDocument())
      // still shows the button (not the done message)
      expect(getByRole('button', { name: /mark ce debates as read/i })).toBeInTheDocument()
    } finally { delete global.fetch }
  })
})
