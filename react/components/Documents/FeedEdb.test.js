import React from 'react'
import { render, fireEvent, waitFor } from '@testing-library/react'
import FeedEdb from './FeedEdb'
import fixture from '../../__fixtures__/pagestate/feed_edb.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('FeedEdb (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<FeedEdb data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<FeedEdb data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// #4390: the admin gate reads from the global `user` prop, NOT from page contentData
// (which used to re-emit is_admin -- the same viewer flag shipped twice).
describe('FeedEdb — admin gate from the user prop (#4390)', () => {
  const adminData = {
    type: 'feed_edb',
    message: '',
    current_count: 0,
    action_taken: 0,
    borg_options: [-1, 0, 1]
  }
  const escapeData = {
    type: 'feed_edb',
    message: "You narrowly escape EDB's mouth."
  }

  it('shows admin-only EDB content when user.admin is true', () => {
    const { container } = render(<FeedEdb data={adminData} user={{ admin: true }} />)
    expect(container.textContent).toMatch(/your current borged count/i)
    expect(container.textContent).not.toMatch(/narrowly escape/i)
  })

  it('hides admin-only content for a non-admin user (renders escape message)', () => {
    const { container } = render(<FeedEdb data={escapeData} user={{ admin: false }} />)
    expect(container.textContent).toMatch(/narrowly escape/i)
    expect(container.textContent).not.toMatch(/your current borged count/i)
  })

  it('treats a missing user prop as non-admin (no crash)', () => {
    const { container } = render(<FeedEdb data={escapeData} user={undefined} />)
    expect(container.textContent).toMatch(/narrowly escape/i)
    expect(container.textContent).not.toMatch(/your current borged count/i)
  })
})

// #4390 → API: the borg action now POSTs to /api/feed_edb/borg (was a ?numborgings= page
// reload that mutated inside the page controller) and updates inline.
describe('FeedEdb — borg action drives the API', () => {
  const adminData = { type: 'feed_edb', current_count: 0, borg_options: [-1, 0, 5] }
  afterEach(() => { jest.restoreAllMocks(); delete global.fetch })

  it('POSTs the chosen count to /api/feed_edb/borg and shows the result', async () => {
    const fetchMock = (global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ success: 1, message: 'Simulating being borged 5 times.', current_count: 5 }),
    }))
    const { container, getByRole } = render(<FeedEdb data={adminData} user={{ admin: true }} />)
    fireEvent.click(getByRole('button', { name: '5' }))
    await waitFor(() => expect(container.textContent).toMatch(/borged 5 times/i))
    expect(fetchMock).toHaveBeenCalledWith('/api/feed_edb/borg', expect.objectContaining({
      method: 'POST',
      body: JSON.stringify({ numborgings: 5 }),
    }))
    // count updates from the response, not a reload
    expect(container.textContent).toMatch(/current borged count:\s*5/i)
  })

  it('renders an initial count of 0 as "0", not blank', () => {
    const { container } = render(<FeedEdb data={{ type: 'feed_edb', current_count: 0, borg_options: [0, 1] }} user={{ admin: true }} />)
    const countP = container.querySelector('.feed-edb > p')
    expect(countP.textContent.replace(/\s+/g, ' ').trim()).toBe('Your current borged count: 0')
  })

  it('renders a cleared count (unborg -> 0) as "0", not blank', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ success: 1, message: 'Unborged.', current_count: 0 }),
    })
    const { container, getByRole } = render(<FeedEdb data={{ type: 'feed_edb', current_count: 5, borg_options: [-1, 0, 5] }} user={{ admin: true }} />)
    fireEvent.click(getByRole('button', { name: '0' }))
    await waitFor(() => expect(container.textContent).toMatch(/unborged/i))
    const clearedCountP = container.querySelector('.feed-edb > p')
    expect(clearedCountP.textContent.replace(/\s+/g, ' ').trim()).toBe('Your current borged count: 0')
  })

  it('surfaces an API error (e.g. non-admin) instead of crashing', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ success: 0, error: 'Admins only' }),
    })
    const { container, getByRole } = render(<FeedEdb data={adminData} user={{ admin: true }} />)
    fireEvent.click(getByRole('button', { name: '-1' }))
    await waitFor(() => expect(container.textContent).toMatch(/admins only/i))
  })
})
