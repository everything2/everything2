import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import CollaborationEdit from './CollaborationEdit'

// CollaborationEdit drives five collab-scoped mutations against
// /api/collaborations/:id/action/{save,removemember,unlock,delete} (+ addmember via search).
// These lock the endpoint + payload for the ones that don't depend on the rich editor; the
// doctext save is exercised in HTML mode (localStorage) so it doesn't hang on TipTap readiness.

const makeData = (o = {}) => ({
  collaboration: { node_id: 800, title: 'Team Doc', public: 0, doctext: 'hello world' },
  members: [{ node_id: 11, title: 'alice', type: 'user' }],
  can_manage_members: true,
  user: { is_admin: true },
  ...o,
})

describe('CollaborationEdit interaction', () => {
  beforeEach(() => {
    // force HTML editor mode so save() doesn't depend on the rich (TipTap) editor being ready
    try { window.localStorage.setItem('e2_editor_mode', 'html') } catch (e) { /* ignore */ }
  })
  afterEach(() => {
    jest.restoreAllMocks()
    delete global.fetch
    try { window.localStorage.clear() } catch (e) { /* ignore */ }
  })

  it('renders nothing without data', () => {
    const { container } = render(<CollaborationEdit data={null} />)
    expect(container).toBeEmptyDOMElement()
  })

  it('saves content + the public flag to /action/save', async () => {
    global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: true }) })
    render(<CollaborationEdit data={makeData()} />)
    fireEvent.click(screen.getByRole('checkbox')) // toggle public on
    fireEvent.click(screen.getByRole('button', { name: /save changes/i }))

    await waitFor(() =>
      expect(global.fetch).toHaveBeenCalledWith('/api/collaborations/800/action/save', expect.objectContaining({ method: 'POST' }))
    )
    expect(JSON.parse(global.fetch.mock.calls[0][1].body)).toEqual({ doctext: 'hello world', public: 1 })
    await waitFor(() => expect(screen.getByText(/saved successfully/i)).toBeInTheDocument())
  })

  it('removes a member via /action/removemember', async () => {
    global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: true }) })
    render(<CollaborationEdit data={makeData()} />)
    fireEvent.click(screen.getByRole('button', { name: 'Remove' }))

    await waitFor(() =>
      expect(global.fetch).toHaveBeenCalledWith('/api/collaborations/800/action/removemember', expect.objectContaining({ method: 'POST' }))
    )
    expect(JSON.parse(global.fetch.mock.calls[0][1].body)).toEqual({ node_id: 11 })
  })

  it('unlocks via /action/unlock', async () => {
    global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: true }) })
    render(<CollaborationEdit data={makeData()} />)
    fireEvent.click(screen.getByRole('button', { name: /unlock/i }))
    await waitFor(() =>
      expect(global.fetch).toHaveBeenCalledWith('/api/collaborations/800/action/unlock', expect.objectContaining({ method: 'POST' }))
    )
  })

  it('deletes through the confirm modal via /action/delete (admin)', async () => {
    global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: true }) })
    render(<CollaborationEdit data={makeData()} />)
    // header trigger is lowercase "delete"; the modal's confirm button is "Delete"
    fireEvent.click(screen.getByRole('button', { name: 'delete' }))
    fireEvent.click(screen.getByRole('button', { name: 'Delete' }))

    await waitFor(() =>
      expect(global.fetch).toHaveBeenCalledWith('/api/collaborations/800/action/delete', expect.objectContaining({ method: 'POST' }))
    )
  })
})
