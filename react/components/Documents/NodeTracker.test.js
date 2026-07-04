import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import NodeTracker from './NodeTracker'
import fixture from '../../__fixtures__/pagestate/node_tracker.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('NodeTracker (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<NodeTracker data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<NodeTracker data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// Interaction coverage (#4458): the "update" snapshot-save moved to POST
// /api/node_tracker/update, so the button fetches the refreshed payload and re-renders in
// place (was a full-page GET reload with ?update=1).
describe('NodeTracker interaction (#4458)', () => {
  afterEach(() => {
    jest.restoreAllMocks()
    delete global.fetch
  })

  const base = {
    last_update: '2020-01-01 00:00',
    stats: {},
    type_breakdown: [],
    published_nodes: [],
    removed_nodes: [],
    renamed_nodes: [],
    changed_nodes: [],
    has_changes: false,
  }

  it('Update posts to /api/node_tracker/update and refreshes last_update in place', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ success: 1, last_update: '2026-07-03 12:00', stats: {}, has_changes: false }),
    })
    const { container } = render(<NodeTracker data={base} />)
    expect(container.textContent).toMatch(/2020-01-01 00:00/)
    fireEvent.click(screen.getByRole('button', { name: /update/i }))
    await waitFor(() =>
      expect(global.fetch).toHaveBeenCalledWith('/api/node_tracker/update', expect.objectContaining({ method: 'POST' }))
    )
    await waitFor(() => expect(container.textContent).toMatch(/2026-07-03 12:00/))
  })

  it('renders the static intro as real LinkNode links (not lifted E2 markup)', () => {
    render(<NodeTracker data={base} />)
    // The [cow of doom] / [pbuh] / [kthejoker|me] E2 markup is now real anchors, with no
    // literal brackets leaking through.
    const cow = screen.getByRole('link', { name: 'cow of doom' })
    expect(cow).toHaveAttribute('href', '/title/cow of doom')
    expect(screen.getByRole('link', { name: 'me' })).toHaveAttribute('href', '/title/kthejoker')
    expect(screen.queryByText(/\[cow of doom\]|\[pbuh\]|\[kthejoker/)).toBeNull()
  })

  it('keeps the static intro after an update (merge, not replace)', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ success: 1, last_update: 'x', stats: {}, has_changes: false }),
    })
    render(<NodeTracker data={base} />)
    fireEvent.click(screen.getByRole('button', { name: /update/i }))
    await waitFor(() => expect(global.fetch).toHaveBeenCalled())
    expect(screen.getByRole('link', { name: 'cow of doom' })).toBeInTheDocument()
  })
})
