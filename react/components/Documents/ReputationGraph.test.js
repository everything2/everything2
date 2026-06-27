import React from 'react'
import { render, waitFor } from '@testing-library/react'
import ReputationGraph from './ReputationGraph'
import fixture from '../../__fixtures__/pagestate/reputation_graph.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('ReputationGraph (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<ReputationGraph data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<ReputationGraph data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

describe('ReputationGraph admin-note gating (role from user prop)', () => {
  // Viewable writeup so the component renders past the access-denied/loading gates.
  const data = {
    type: 'reputation_graph',
    layout: 'vertical',
    writeup: { node_id: 123, title: 'a writeup', publishtime: '2026-01-01' },
    author: { node_id: 456, title: 'someauthor' },
    can_view: 1
  }
  const graphPayload = { success: true, data: { months: [{ label: 'Jan 2026', upvotes: 1, downvotes: 0, reputation: 1, is_january: true }] } }

  beforeEach(() => {
    global.fetch = jest.fn(() => Promise.resolve({ json: () => Promise.resolve(graphPayload) }))
  })
  afterEach(() => {
    delete global.fetch
  })

  it('shows the admin URL-append note when user.admin is true', async () => {
    const { container } = render(<ReputationGraph data={data} user={{ admin: true }} />)
    await waitFor(() => expect(container.textContent).toMatch(/Admins can view the graph/))
  })

  it('hides the admin note when user.admin is false', async () => {
    const { container } = render(<ReputationGraph data={data} user={{ admin: false }} />)
    await waitFor(() => expect(container.textContent).toMatch(/monthly reputation graph/i))
    expect(container.textContent).not.toMatch(/Admins can view the graph/)
  })

  it('does not crash when user prop is undefined (note hidden)', async () => {
    const { container } = render(<ReputationGraph data={data} user={undefined} />)
    await waitFor(() => expect(container.textContent).toMatch(/monthly reputation graph/i))
    expect(container.textContent).not.toMatch(/Admins can view the graph/)
  })
})
