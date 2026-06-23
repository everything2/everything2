import React from 'react'
import { render, screen, fireEvent, waitFor, within } from '@testing-library/react'
import NodeToolset from './NodeToolset'

// NodeToolset is the admin node action panel. It drives four fetch paths, all
// keyed off response.ok (not a success flag):
//   GET  /api/admin/node/:id           (load edit modal)
//   POST /api/admin/node/:id/edit      (save edits)
//   POST /api/nodes/:id/action/delete  (nuke)
//   POST /api/nodes/:id/action/clone   (clone)
// On the mutating paths it redirects via window.location.href. (#4198)
describe('NodeToolset (API-backed)', () => {
  const baseProps = {
    nodeId: 42,
    nodeTitle: 'Some Node',
    nodeType: 'superdoc', // a system node -> Edit uses the modal/API path
    canDelete: true,
    currentDisplay: 'display',
    hasHelp: false,
    isWriteup: false,
    preventNuke: false
  }

  let originalLocation
  beforeEach(() => {
    originalLocation = window.location
    delete window.location
    window.location = { href: '' }
  })
  afterEach(() => {
    window.location = originalLocation
    jest.restoreAllMocks()
  })

  const okJson = (body) => Promise.resolve({ ok: true, json: async () => body })
  const errJson = (body) => Promise.resolve({ ok: false, json: async () => body })

  it('clones the node via /api/nodes/:id/action/clone and redirects to the clone', async () => {
    const fetchMock = (global.fetch = jest.fn(() => okJson({ cloned_node_id: 777 })))

    render(<NodeToolset {...baseProps} />)
    fireEvent.click(screen.getByRole('button', { name: /Clone Node/ }))

    // the clone modal input
    const input = await screen.findByPlaceholderText('Enter title for cloned node')
    fireEvent.change(input, { target: { value: 'Cloned Copy' } })

    // the modal action button (distinct from the toolset-grid trigger)
    const cloneButtons = screen.getAllByRole('button', { name: /Clone Node/ })
    fireEvent.click(cloneButtons[cloneButtons.length - 1])

    await waitFor(() => expect(fetchMock).toHaveBeenCalled())
    const [url, opts] = fetchMock.mock.calls[0]
    expect(url).toBe('/api/nodes/42/action/clone')
    expect(opts.method).toBe('POST')
    expect(JSON.parse(opts.body)).toEqual({ title: 'Cloned Copy' })

    await waitFor(() => expect(window.location.href).toBe('/?node_id=777'))
  })

  it('nukes the node via /api/nodes/:id/action/delete and redirects', async () => {
    const fetchMock = (global.fetch = jest.fn(() => okJson({ success: 1 })))

    render(<NodeToolset {...baseProps} />)
    fireEvent.click(screen.getByRole('button', { name: /Delete Node/ }))

    // the nuke modal opens with its confirmation copy
    await screen.findByText(/removes it immediately/)
    // the modal confirm button is the last "Delete Node" match (grid trigger + modal action)
    const deleteButtons = screen.getAllByRole('button', { name: /Delete Node/ })
    fireEvent.click(deleteButtons[deleteButtons.length - 1])

    await waitFor(() => expect(fetchMock).toHaveBeenCalled())
    const [url, opts] = fetchMock.mock.calls[0]
    expect(url).toBe('/api/nodes/42/action/delete')
    expect(opts.method).toBe('POST')

    await waitFor(() => expect(window.location.href).toBe('/?node_id=42'))
  })

  it('loads node data into the edit modal then saves changed fields via /edit', async () => {
    const fetchMock = (global.fetch = jest.fn((url, opts) => {
      if (opts && opts.method === 'POST') {
        return okJson({ title: 'Renamed Node' })
      }
      // GET load
      return okJson({
        title: 'Some Node',
        author_user: { title: 'root' },
        maintainedby_user: { title: 'maintainer1' },
        createtime: '2020-01-01'
      })
    }))

    render(<NodeToolset {...baseProps} />)
    fireEvent.click(screen.getByRole('button', { name: /Edit Node/ }))

    // GET fires on open; title input pre-fills from loaded data
    await waitFor(() => expect(screen.getByDisplayValue('Some Node')).toBeInTheDocument())
    const getCall = fetchMock.mock.calls.find(([, o]) => !o || o.method === 'GET')
    expect(getCall[0]).toBe('/api/admin/node/42')

    // change the title, then save
    fireEvent.change(screen.getByDisplayValue('Some Node'), { target: { value: 'Renamed Node' } })
    fireEvent.click(screen.getByRole('button', { name: /Save Changes/ }))

    await waitFor(() => {
      const post = fetchMock.mock.calls.find(([, o]) => o && o.method === 'POST')
      expect(post).toBeTruthy()
    })
    const post = fetchMock.mock.calls.find(([, o]) => o && o.method === 'POST')
    expect(post[0]).toBe('/api/admin/node/42/edit')
    expect(JSON.parse(post[1].body)).toEqual({ title: 'Renamed Node' })

    await waitFor(() => expect(window.location.href).toBe('/title/' + encodeURIComponent('Renamed Node')))
  })

  it('surfaces an API error from a failed clone and does not redirect', async () => {
    global.fetch = jest.fn(() => errJson({ error: 'A node with that title already exists.' }))

    render(<NodeToolset {...baseProps} />)
    fireEvent.click(screen.getByRole('button', { name: /Clone Node/ }))
    const input = await screen.findByPlaceholderText('Enter title for cloned node')
    fireEvent.change(input, { target: { value: 'Dup' } })

    const cloneButtons = screen.getAllByRole('button', { name: /Clone Node/ })
    fireEvent.click(cloneButtons[cloneButtons.length - 1])

    await waitFor(() =>
      expect(screen.getByText('A node with that title already exists.')).toBeInTheDocument()
    )
    expect(window.location.href).toBe('')
  })
})
