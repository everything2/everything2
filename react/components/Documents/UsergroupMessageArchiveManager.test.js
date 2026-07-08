import React from 'react'
import { render, screen, fireEvent, waitFor, within } from '@testing-library/react'
import UsergroupMessageArchiveManager from './UsergroupMessageArchiveManager'
import fixture from '../../__fixtures__/pagestate/usergroup_message_archive_manager.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('UsergroupMessageArchiveManager (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<UsergroupMessageArchiveManager data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<UsergroupMessageArchiveManager data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// Interaction coverage (#4479, Refs #4298): the archive on/off write moved to
// POST /api/usergroup_message_archive_manager/apply; the page is now pure-render.
describe('UsergroupMessageArchiveManager interaction (#4479)', () => {
  const data = {
    node_id: 500,
    archive_node_id: 900,
    usergroups: [
      { group_id: 11, group_title: 'edev', is_archiving: 0 },
      { group_id: 12, group_title: 'gods', is_archiving: 1 },
    ],
    num_archiving: 1,
    num_not_archiving: 1,
    changes: [],
  }

  afterEach(() => {
    jest.restoreAllMocks()
    delete global.fetch
  })

  it('shows the admin error branch', () => {
    render(<UsergroupMessageArchiveManager data={{ error: 'This page is restricted to administrators.' }} />)
    expect(screen.getByText(/restricted to administrators/i)).toBeInTheDocument()
  })

  it('only posts changes where the checkbox is ticked AND an action is chosen', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        success: 1,
        changes: [{ group_id: 11, group_title: 'edev', action: 'enabled' }],
        usergroups: [
          { group_id: 11, group_title: 'edev', is_archiving: 1 },
          { group_id: 12, group_title: 'gods', is_archiving: 1 },
        ],
        num_archiving: 2,
        num_not_archiving: 0,
      }),
    })
    render(<UsergroupMessageArchiveManager data={data} />)

    // edev: tick the checkbox + choose "start archiving" (2)
    fireEvent.click(document.querySelector('input[name="umam_sure_id_11"]'))
    fireEvent.change(document.querySelector('select[name="umam_what_id_11"]'), { target: { value: '2' } })
    // gods: choose an action but DON'T tick the checkbox -> must be excluded
    fireEvent.change(document.querySelector('select[name="umam_what_id_12"]'), { target: { value: '1' } })

    fireEvent.click(screen.getByRole('button', { name: /^submit$/i }))

    await waitFor(() =>
      expect(global.fetch).toHaveBeenCalledWith('/api/usergroup_message_archive_manager/apply', expect.objectContaining({ method: 'POST' }))
    )
    // only edev (checked + action 2); gods excluded (unchecked)
    expect(JSON.parse(global.fetch.mock.calls[0][1].body)).toEqual({ changes: [{ group_id: 11, action: '2' }] })
    // re-renders the applied changes from the response
    await waitFor(() => expect(screen.getByText(/Enabled auto-archive for/i)).toBeInTheDocument())
  })

  it('surfaces a 200 + {success:0} reject as an error', async () => {
    global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: 0, error: 'nope' }) })
    render(<UsergroupMessageArchiveManager data={data} />)
    fireEvent.click(document.querySelector('input[name="umam_sure_id_11"]'))
    fireEvent.change(document.querySelector('select[name="umam_what_id_11"]'), { target: { value: '2' } })
    fireEvent.click(screen.getByRole('button', { name: /^submit$/i }))
    await waitFor(() => expect(screen.getByText('nope')).toBeInTheDocument())
  })
})
