import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import Settings from './Settings'

// Settings is the preferences hub: one "Save Changes" button whose handleSave fires a POST
// per *changed* section (settings/advanced prefs -> /api/preferences/set, nodelet order ->
// /api/nodelets, notifications -> /api/preferences/notifications, editor macros ->
// /api/preferences/admin, profile -> /api/user/edit). These tests lock the two things most
// likely to break silently on the routing/ORM churn ahead: (a) only-changed keys are sent to
// the right endpoint, and (b) untouched sections are NOT posted (dirty gating). The peripheral
// list managers are stubbed so the test targets handleSave, not their internals.
jest.mock('../UserInteractions/FavoriteUsersManager', () => () => null)
jest.mock('../UserInteractions/UserInteractionsManager', () => () => null)

const baseData = (overrides = {}) => ({
  defaultTab: 'settings',
  settingsPreferences: { votesafety: 0, coolsafety: 0 },
  advancedPreferences: {},
  nodelets: [],
  availableNodelets: [],
  notificationPreferences: [],
  nodeletSettings: {},
  editorPreferences: {},
  macros: [],
  blockedUsers: [],
  favoriteUsers: [],
  availableStylesheets: [],
  profileData: {},
  ...overrides,
})
const user = { node_id: 100, title: 'tester', editor: false }
const saveBtn = () => screen.getByRole('button', { name: /save changes/i })

describe('Settings save contract', () => {
  afterEach(() => {
    jest.restoreAllMocks()
    delete global.fetch
  })

  it('shows the guest message and fires no network for a guest payload', () => {
    global.fetch = jest.fn()
    render(<Settings data={{ error: 'guest', message: 'You must be logged in to change settings.' }} user={undefined} />)
    expect(screen.getByText(/must be logged in to change settings/i)).toBeInTheDocument()
    expect(global.fetch).not.toHaveBeenCalled()
  })

  it('keeps Save disabled until something changes', () => {
    global.fetch = jest.fn()
    render(<Settings data={baseData()} user={user} />)
    expect(saveBtn()).toBeDisabled()
    fireEvent.click(screen.getByRole('checkbox', { name: /confirmation when voting/i }))
    expect(saveBtn()).toBeEnabled()
    expect(screen.getByText(/unsaved changes/i)).toBeInTheDocument()
  })

  it('posts only the changed preference to /api/preferences/set and shows success', async () => {
    global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: true }) })
    render(<Settings data={baseData()} user={user} />)

    fireEvent.click(screen.getByRole('checkbox', { name: /confirmation when voting/i }))
    fireEvent.click(saveBtn())

    await waitFor(() => expect(global.fetch).toHaveBeenCalledWith('/api/preferences/set', expect.objectContaining({ method: 'POST' })))
    const body = JSON.parse(global.fetch.mock.calls[0][1].body)
    // only the toggled key, flipped 0 -> 1; the untouched coolsafety is omitted
    expect(body).toEqual({ votesafety: 1 })

    await waitFor(() => expect(screen.getByText(/saved successfully/i)).toBeInTheDocument())
  })

  it('does NOT post the profile or nodelet endpoints when only a preference changed (dirty gating)', async () => {
    global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: true }) })
    render(<Settings data={baseData()} user={user} />)

    fireEvent.click(screen.getByRole('checkbox', { name: /confirmation when cooling/i }))
    fireEvent.click(saveBtn())

    await waitFor(() => expect(global.fetch).toHaveBeenCalledWith('/api/preferences/set', expect.anything()))
    const urls = global.fetch.mock.calls.map((c) => String(c[0]))
    expect(urls).not.toContain('/api/user/edit')
    expect(urls).not.toContain('/api/nodelets')
    expect(urls).not.toContain('/api/preferences/notifications')
  })

  it('surfaces the error banner when a section save fails', async () => {
    global.fetch = jest.fn().mockResolvedValue({ ok: false, json: async () => ({ message: 'server on fire' }) })
    render(<Settings data={baseData()} user={user} />)

    fireEvent.click(screen.getByRole('checkbox', { name: /confirmation when voting/i }))
    fireEvent.click(saveBtn())

    await waitFor(() => expect(screen.getByText(/server on fire/i)).toBeInTheDocument())
    expect(screen.queryByText(/saved successfully/i)).toBeNull()
  })
})
