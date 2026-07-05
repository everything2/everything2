import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import CategoryEdit from './CategoryEdit'

// CategoryEdit's category-specific mutations: member removal (/api/category/remove_member) and
// the meta/settings save (/api/category/update_meta). The doctext save (/api/category/update) is
// the same rich-editor save pattern covered by CollaborationEdit, so it's not duplicated here.

const makeData = (o = {}) => ({
  category: {
    node_id: 950,
    title: 'My Category',
    description: '',
    author: { node_id: 2, title: 'owner' },
    author_id: 2,
    is_public: true,
  },
  viewer: { node_id: 2, is_admin: true },
  members: [{ node_id: 11, title: 'a sub-node', type: 'e2node' }],
  can_edit_meta: true,
  can_manage_members: true,
  guest_user_id: 3,
  ...o,
})

describe('CategoryEdit interaction', () => {
  beforeEach(() => {
    try { window.localStorage.setItem('e2_editor_mode', 'html') } catch (e) { /* ignore */ }
  })
  afterEach(() => {
    jest.restoreAllMocks()
    delete global.fetch
    try { window.localStorage.clear() } catch (e) { /* ignore */ }
  })

  it('removes a member (after confirm) via /api/category/remove_member', async () => {
    jest.spyOn(window, 'confirm').mockReturnValue(true)
    global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: true }) })
    render(<CategoryEdit data={makeData()} />)
    fireEvent.click(screen.getByRole('button', { name: /remove from category/i }))

    await waitFor(() =>
      expect(global.fetch).toHaveBeenCalledWith('/api/category/remove_member', expect.objectContaining({ method: 'POST' }))
    )
    expect(JSON.parse(global.fetch.mock.calls[0][1].body)).toEqual({ node_id: 950, member_id: 11 })
    // removed from the list
    await waitFor(() => expect(screen.queryByText('a sub-node')).toBeNull())
  })

  it('saves category meta via /api/category/update_meta (public -> author_user is the guest id)', async () => {
    global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: true }) })
    render(<CategoryEdit data={makeData()} />)

    // a title edit flips hasMetaChanges and enables the settings save
    fireEvent.change(screen.getByDisplayValue('My Category'), { target: { value: 'Renamed Category' } })
    fireEvent.click(screen.getByRole('button', { name: /save settings/i }))

    await waitFor(() =>
      expect(global.fetch).toHaveBeenCalledWith('/api/category/update_meta', expect.objectContaining({ method: 'POST' }))
    )
    expect(JSON.parse(global.fetch.mock.calls[0][1].body)).toEqual({
      node_id: 950,
      title: 'Renamed Category',
      author_user: 3, // public category -> owned by the guest/system user
    })
    await waitFor(() => expect(screen.getByText(/settings saved/i)).toBeInTheDocument())
  })
})
