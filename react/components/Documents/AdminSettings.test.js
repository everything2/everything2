import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import AdminSettings from './AdminSettings'

// AdminSettings: editor display prefs + chatterbox macro management. The save
// moved to POST /api/preferences/admin; the component owns the dirty/save state
// and transforms macro text (curly braces -> square brackets) before posting.
describe('AdminSettings error branches', () => {
  it('renders the guest error with register/login links', () => {
    render(<AdminSettings data={{ error: 'guest' }} />)
    expect(screen.getByRole('link', { name: /register/i })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: /log in/i })).toBeInTheDocument()
  })

  it('renders the permission error for non-editors', () => {
    render(<AdminSettings data={{ error: 'permission' }} />)
    expect(screen.getByText(/only available to content editors/i)).toBeInTheDocument()
  })
})

describe('AdminSettings interaction', () => {
  afterEach(() => {
    jest.restoreAllMocks()
    delete global.fetch
  })

  const baseData = {
    editorPreferences: { hidenodenotes: 0 },
    macros: [{ name: 'test', text: '/say hi {node}', enabled: 1 }],
    maxMacroLength: 768,
    currentUser: { node_id: 1 },
  }

  it('renders macros from the payload and starts with Save disabled', () => {
    render(<AdminSettings data={baseData} />)
    expect(screen.getByText('test')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /save settings/i })).toBeDisabled()
  })

  it('toggling a preference marks the form dirty and enables Save', () => {
    render(<AdminSettings data={baseData} />)
    const cb = screen.getByLabelText(/hide node notes/i)
    fireEvent.click(cb)
    expect(screen.getByText(/unsaved changes/i)).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /save settings/i })).toBeEnabled()
  })

  it('saves via POST /api/preferences/admin, converting curly braces to square brackets', async () => {
    global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: 1 }) })
    render(<AdminSettings data={baseData} />)
    fireEvent.click(screen.getByLabelText(/hide node notes/i))
    fireEvent.click(screen.getByRole('button', { name: /save settings/i }))

    await waitFor(() => expect(global.fetch).toHaveBeenCalled())
    const [url, opts] = global.fetch.mock.calls[0]
    expect(url).toBe('/api/preferences/admin')
    expect(opts.method).toBe('POST')
    const body = JSON.parse(opts.body)
    expect(body.settings.hidenodenotes).toBe(1)
    // enabled macro's braces are rewritten for storage
    expect(body.macros.test).toBe('/say hi [node]')

    await waitFor(() => expect(screen.getByText(/saved successfully/i)).toBeInTheDocument())
  })

  it('surfaces the API error when the save fails', async () => {
    global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: 0, error: 'nope' }) })
    render(<AdminSettings data={baseData} />)
    fireEvent.click(screen.getByLabelText(/hide node notes/i))
    fireEvent.click(screen.getByRole('button', { name: /save settings/i }))
    await waitFor(() => expect(screen.getByText('nope')).toBeInTheDocument())
  })

  it('sends null for a disabled macro so the server deletes it', async () => {
    global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: 1 }) })
    render(<AdminSettings data={baseData} />)
    // uncheck the macro's "Use?" box -> becomes a delete on save
    const useBox = screen.getAllByRole('checkbox').find((c) => c !== screen.getByLabelText(/hide node notes/i))
    fireEvent.click(useBox)
    fireEvent.click(screen.getByRole('button', { name: /save settings/i }))
    await waitFor(() => expect(global.fetch).toHaveBeenCalled())
    const body = JSON.parse(global.fetch.mock.calls[0][1].body)
    expect(body.macros.test).toBeNull()
  })
})
