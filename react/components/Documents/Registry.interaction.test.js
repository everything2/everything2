import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import Registry from './Registry'

// Registry drives three mutations against /api/registrations/:id/action/{submit,delete,admin_delete}.
// These lock the endpoint + payload for each, plus the guest gate.

const makeData = (o = {}) => ({
  registry: { node_id: 900, title: 'The Registry', input_style: 'text', author: { node_id: 1, title: 'admin' } },
  entries: [],
  user_entry: null,
  is_guest: false,
  is_admin: false,
  ...o,
})

describe('Registry interaction', () => {
  afterEach(() => {
    jest.restoreAllMocks()
    delete global.fetch
  })

  it('shows the guest message (no form) for a guest', () => {
    render(<Registry data={makeData({ is_guest: true })} />)
    expect(document.querySelector('.registry__guest-message')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /^submit$/i })).toBeNull()
  })

  it('submits an entry to /action/submit and shows the success message', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ success: true, entries: [], user_entry: {}, message: 'Entry saved' }),
    })
    render(<Registry data={makeData()} />)
    fireEvent.change(screen.getByPlaceholderText(/enter your data/i), { target: { value: 'my entry' } })
    fireEvent.click(screen.getByRole('button', { name: /^submit$/i }))

    await waitFor(() =>
      expect(global.fetch).toHaveBeenCalledWith('/api/registrations/900/action/submit', expect.objectContaining({ method: 'POST' }))
    )
    expect(JSON.parse(global.fetch.mock.calls[0][1].body)).toEqual({ data: 'my entry', comments: '', in_user_profile: false })
    await waitFor(() => expect(screen.getByText(/entry saved/i)).toBeInTheDocument())
  })

  it('removes the user\'s own entry (after confirm) via /action/delete', async () => {
    jest.spyOn(window, 'confirm').mockReturnValue(true)
    global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: true, entries: [], message: 'Removed' }) })
    render(<Registry data={makeData({ user_entry: { data: 'mine', in_user_profile: false } })} />)
    fireEvent.click(screen.getByRole('button', { name: /remove my entry/i }))

    await waitFor(() =>
      expect(global.fetch).toHaveBeenCalledWith('/api/registrations/900/action/delete', expect.objectContaining({ method: 'POST' }))
    )
  })

  it('lets an admin delete another entry (after confirm) via /action/admin_delete', async () => {
    jest.spyOn(window, 'confirm').mockReturnValue(true)
    global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: true, entries: [], message: 'Deleted' }) })
    render(
      <Registry
        data={makeData({ is_admin: true, entries: [{ user_id: 5, username: 'alice', data: 'x', in_user_profile: false }] })}
      />
    )
    fireEvent.click(screen.getByRole('button', { name: /delete entry for alice/i }))

    await waitFor(() =>
      expect(global.fetch).toHaveBeenCalledWith('/api/registrations/900/action/admin_delete', expect.objectContaining({ method: 'POST' }))
    )
    expect(JSON.parse(global.fetch.mock.calls[0][1].body)).toEqual({ user_id: 5 })
  })
})
