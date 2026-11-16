import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import Modal from 'react-modal'
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

  it('surfaces the error banner when a section save fails (HTTP-level error)', async () => {
    global.fetch = jest.fn().mockResolvedValue({ ok: false, json: async () => ({ message: 'server on fire' }) })
    render(<Settings data={baseData()} user={user} />)

    fireEvent.click(screen.getByRole('checkbox', { name: /confirmation when voting/i }))
    fireEvent.click(saveBtn())

    await waitFor(() => expect(screen.getByText(/server on fire/i)).toBeInTheDocument())
    expect(screen.queryByText(/saved successfully/i)).toBeNull()
  })

  it('treats a 200 + {success:0} preference reject as a failure, not a silent success', async () => {
    // Contract: /api/preferences/set now returns HTTP 200 with {success:0,error} on a validation
    // reject (response-code recut). The component must NOT read that as "saved".
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ success: 0, error: 'Invalid preference value' }),
    })
    render(<Settings data={baseData()} user={user} />)

    fireEvent.click(screen.getByRole('checkbox', { name: /confirmation when voting/i }))
    fireEvent.click(saveBtn())

    await waitFor(() => expect(screen.getByText(/invalid preference value/i)).toBeInTheDocument())
    expect(screen.queryByText(/saved successfully/i)).toBeNull()
  })

  it('profile tab shows the current image from the URL the server builds (#4643)', () => {
    const url = 'https://s3-us-west-2.amazonaws.com/hnimagew.everything2.com/tester?v=1731772640'
    const { container } = render(<Settings data={baseData({ defaultTab: 'profile', profileData: { email: 'a@b.c', imgsrc: '/tester?v=1731772640', imgsrc_url: url } })} user={user} />)
    expect(container.querySelector('img.settings-profile-image')).toHaveAttribute('src', url)
  })

  describe('profile tab: current password and unsaved state (#4637)', () => {
    const profileData = { realname: 'Real Name', email: 'a@b.c', doctext: '', mission: '', specialties: '', employment: '', motto: '' }
    const renderProfile = () => render(<Settings data={baseData({ defaultTab: 'profile', profileData })} user={user} />)
    const field = (container, name) => container.querySelector(`input[name="${name}"]`)
    const setField = (container, name, value) => fireEvent.change(field(container, name), { target: { name, value } })
    const leaveWarns = () => {
      const event = new Event('beforeunload', { cancelable: true })
      window.dispatchEvent(event)
      return event.defaultPrevented
    }
    // The prompt is a react-modal dialog, rendered in a portal outside the component's container.
    const dialog = () => screen.queryByRole('dialog')
    const confirmWith = (password) => {
      fireEvent.change(screen.getByLabelText('Current password'), { target: { value: password } })
      fireEvent.click(screen.getByRole('button', { name: /^confirm$/i }))
    }
    const setConfirm = (value) => fireEvent.change(screen.getByPlaceholderText(/re-enter new password/i), { target: { value } })
    const editCalls = () => global.fetch.mock.calls.filter(([url]) => url === '/api/user/edit')

    beforeAll(() => Modal.setAppElement(document.createElement('div')))

    it('saves other profile fields without asking for the current password', async () => {
      global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: true }) })
      const { container } = renderProfile()
      setField(container, 'realname', 'Only The Name')
      fireEvent.click(saveBtn())
      await waitFor(() => expect(editCalls()).toHaveLength(1))
      expect(dialog()).toBeNull()
      expect(JSON.parse(editCalls()[0][1].body)).not.toHaveProperty('current_password')
    })

    it('an email change asks for the current password in a modal, then sends it', async () => {
      global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: true }) })
      const { container } = renderProfile()
      expect(field(container, 'current_password')).toBeNull() // no inline field on the form

      setField(container, 'email', 'new@example.com')
      fireEvent.click(saveBtn())
      expect(dialog()).not.toBeNull()
      expect(screen.getByText(/to change your email, enter your current password/i)).toBeInTheDocument()
      expect(global.fetch).not.toHaveBeenCalled()

      confirmWith('my-current-pass')
      await waitFor(() => expect(editCalls()).toHaveLength(1))
      expect(JSON.parse(editCalls()[0][1].body)).toMatchObject({ email: 'new@example.com', current_password: 'my-current-pass' })
      await waitFor(() => expect(dialog()).toBeNull())
      expect(screen.getByText(/settings saved successfully/i)).toBeInTheDocument()
    })

    it('a wrong current password keeps the modal open with the error, and a retry succeeds', async () => {
      global.fetch = jest.fn()
        .mockResolvedValueOnce({ ok: true, json: async () => ({ success: 0, code: 'current_password_incorrect', error: 'Your current password is incorrect.' }) })
        .mockResolvedValueOnce({ ok: true, json: async () => ({ success: true }) })
      const { container } = renderProfile()
      setField(container, 'passwd', 'new-pass')
      setConfirm('new-pass')
      fireEvent.click(saveBtn())
      expect(screen.getByText(/to change your password, enter your current password/i)).toBeInTheDocument()

      confirmWith('wrong-pass')
      await waitFor(() => expect(screen.getByRole('alert')).toHaveTextContent(/current password is incorrect/i))
      expect(dialog()).not.toBeNull()
      expect(screen.queryByText(/settings saved successfully/i)).toBeNull()

      confirmWith('right-pass')
      await waitFor(() => expect(dialog()).toBeNull())
      expect(JSON.parse(editCalls()[1][1].body)).toMatchObject({ passwd: 'new-pass', current_password: 'right-pass' })
      expect(field(container, 'passwd').value).toBe('')
    })

    it('cancelling the modal saves nothing and keeps the changes', () => {
      global.fetch = jest.fn()
      const { container } = renderProfile()
      setField(container, 'email', 'new@example.com')
      fireEvent.click(saveBtn())
      fireEvent.click(screen.getByRole('button', { name: /cancel/i }))
      expect(dialog()).toBeNull()
      expect(global.fetch).not.toHaveBeenCalled()
      expect(field(container, 'email').value).toBe('new@example.com')
      expect(leaveWarns()).toBe(true)
    })

    it('mismatched new passwords are reported without opening the modal', () => {
      global.fetch = jest.fn()
      const { container } = renderProfile()
      setField(container, 'passwd', 'new-pass')
      setConfirm('different')
      fireEvent.click(saveBtn())
      expect(dialog()).toBeNull()
      expect(screen.getByText(/error: passwords do not match/i)).toBeInTheDocument()
      expect(global.fetch).not.toHaveBeenCalled()
    })

    it('is clean after a successful save, and dirty again after the next edit', async () => {
      global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: true }) })
      const { container } = renderProfile()

      setField(container, 'realname', 'Saved Name')
      expect(leaveWarns()).toBe(true)
      fireEvent.click(saveBtn())
      await waitFor(() => expect(global.fetch).toHaveBeenCalled())
      await waitFor(() => expect(saveBtn()).toBeDisabled())
      expect(leaveWarns()).toBe(false)
      expect(screen.queryByText(/unsaved changes/i)).toBeNull()

      setField(container, 'motto', 'a new motto')
      await waitFor(() => expect(leaveWarns()).toBe(true))
    })
  })
})
