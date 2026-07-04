import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import NodetypeChanger from './NodetypeChanger'
import fixture from '../../__fixtures__/pagestate/nodetype_changer.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('NodetypeChanger (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<NodetypeChanger data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<NodetypeChanger data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// Interaction coverage (#4461): lookup + change moved to POST /api/nodetype_changer/*, and
// changing into a permanently-cached type is warned in the UI and confirm-gated by the API.
describe('NodetypeChanger interaction (#4461)', () => {
  afterEach(() => {
    jest.restoreAllMocks()
    delete global.fetch
  })

  const nodetypes = [
    { node_id: 3, title: 'document', permanent_cache: 0 },
    { node_id: 14, title: 'superdoc', permanent_cache: 0 },
    { node_id: 153, title: 'setting', permanent_cache: 1 },
  ]
  const baseData = { type: 'nodetype_changer', node_id: 123, nodetypes }

  const lookupOk = { success: 1, target: { node_id: 500, title: 'Some Node', current_type: 'document', type_id: 3 } }

  const doLookup = async () => {
    fireEvent.change(screen.getByRole('textbox'), { target: { value: '500' } })
    fireEvent.click(screen.getByRole('button', { name: /get data/i }))
    await waitFor(() => expect(screen.getByText(/is currently a:/)).toBeInTheDocument())
  }

  it('looks up a node and reveals the change form', async () => {
    global.fetch = jest.fn().mockResolvedValueOnce({ ok: true, json: async () => lookupOk })
    render(<NodetypeChanger data={baseData} />)
    await doLookup()
    expect(global.fetch).toHaveBeenCalledWith('/api/nodetype_changer/lookup', expect.objectContaining({ method: 'POST' }))
    // Title links to the node by id (opens in a new tab so the tool stays open) so you can
    // pop over and verify the change.
    const nodeLink = screen.getByRole('link', { name: 'Some Node' })
    expect(nodeLink).toHaveAttribute('href', '/node/500')
    expect(nodeLink).toHaveAttribute('target', '_blank')
    expect(screen.getByRole('combobox')).toBeInTheDocument()
  })

  it('warns (client-side) when a permanent-cache type is selected', async () => {
    global.fetch = jest.fn().mockResolvedValueOnce({ ok: true, json: async () => lookupOk })
    render(<NodetypeChanger data={baseData} />)
    await doLookup()
    expect(screen.queryByRole('alert')).toBeNull()
    fireEvent.change(screen.getByRole('combobox'), { target: { value: '153' } })
    expect(screen.getByRole('alert')).toHaveTextContent(/permanent/i)
  })

  it('changes to a normal type and shows the success message', async () => {
    global.fetch = jest
      .fn()
      .mockResolvedValueOnce({ ok: true, json: async () => lookupOk })
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({ success: 1, message: "'Some Node' was changed to type 'superdoc'.", target: { node_id: 500, title: 'Some Node', current_type: 'superdoc', type_id: 14 } }),
      })
    render(<NodetypeChanger data={baseData} />)
    await doLookup()
    fireEvent.change(screen.getByRole('combobox'), { target: { value: '14' } })
    fireEvent.click(screen.getByRole('button', { name: /update nodetype/i }))
    await waitFor(() => expect(screen.getByText(/changed to type 'superdoc'/)).toBeInTheDocument())
    expect(global.fetch).toHaveBeenLastCalledWith('/api/nodetype_changer/change', expect.objectContaining({ method: 'POST' }))
  })

  it('requires a second confirm for a permanent-cache target and sends confirmed on retry', async () => {
    global.fetch = jest
      .fn()
      .mockResolvedValueOnce({ ok: true, json: async () => lookupOk })
      .mockResolvedValueOnce({ ok: true, json: async () => ({ success: 0, needs_confirm: 1, warning: 'DANGER: permanent cache fleet-wide' }) })
      .mockResolvedValueOnce({ ok: true, json: async () => ({ success: 1, message: 'done', target: { node_id: 500, title: 'Some Node', current_type: 'setting', type_id: 153 } }) })
    render(<NodetypeChanger data={baseData} />)
    await doLookup()
    fireEvent.change(screen.getByRole('combobox'), { target: { value: '153' } })

    // First submit -> server refuses, asks for confirm
    fireEvent.click(screen.getByRole('button', { name: /update nodetype/i }))
    await waitFor(() => expect(screen.getByRole('alert')).toHaveTextContent(/DANGER/))
    const confirmBtn = screen.getByRole('button', { name: /confirm: change anyway/i })
    expect(confirmBtn).toBeInTheDocument()
    expect(JSON.parse(global.fetch.mock.calls[1][1].body).confirmed).toBe(0)

    // Second submit -> sends confirmed:1, succeeds
    fireEvent.click(confirmBtn)
    await waitFor(() => expect(screen.getByText('done')).toBeInTheDocument())
    expect(JSON.parse(global.fetch.mock.calls[2][1].body).confirmed).toBe(1)
  })

  it('renders the admin-only error with no forms', () => {
    render(<NodetypeChanger data={{ type: 'nodetype_changer', error: 'This page is restricted to administrators.' }} />)
    expect(screen.getByText(/restricted to administrators/i)).toBeInTheDocument()
    expect(screen.queryByRole('button')).toBeNull()
  })
})
