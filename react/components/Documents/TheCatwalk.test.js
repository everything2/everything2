import React from 'react'
import { render, fireEvent, waitFor } from '@testing-library/react'
import TheCatwalk from './TheCatwalk'
import fixture from '../../__fixtures__/pagestate/the_catwalk.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('TheCatwalk (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<TheCatwalk data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<TheCatwalk data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

describe('TheCatwalk guest gating (#4390 contentData dedup, reads user.guest)', () => {
  // Minimal non-guest data so the full browser renders (intro copy, no guest message).
  const memberData = {
    type: 'the_catwalk',
    stylesheets: [],
    current_style: null,
    has_custom_style: 0,
    pagination: { offset: 0, limit: 100, total: 0 },
    sort_options: [{ value: '0', label: '(no sorting)' }],
    current_sort: '0',
    filter: { user_name: '', user_id: 0, is_not: 0 }
  }
  const guestMessage = 'sign up for an account'
  const guestData = { type: 'the_catwalk', message: `This page will allow you to customize your view of the site if you ${guestMessage}.` }

  it('guest viewer (user.guest=true) sees the guest message', () => {
    const { container } = render(<TheCatwalk data={guestData} user={{ guest: true }} />)
    expect(container.textContent).toContain(guestMessage)
    // Member-only browser chrome should be absent.
    expect(container.textContent).not.toContain('every stylesheet ever submitted')
  })

  it('member viewer (user.guest=false) does NOT see the guest message', () => {
    const { container } = render(<TheCatwalk data={memberData} user={{ guest: false }} />)
    expect(container.textContent).not.toContain(guestMessage)
    // Member sees the full stylesheet browser.
    expect(container.textContent).toContain('every stylesheet ever submitted')
  })

  it('undefined user does not crash (treated as non-guest)', () => {
    const { container } = render(<TheCatwalk data={memberData} user={undefined} />)
    expect(container).toBeTruthy()
    expect(container.textContent).toContain('every stylesheet ever submitted')
  })
})

// #4401: clearing a custom style POSTs to /api/customstyle/clear (was a ?clearVandalism GET
// that mutated VARS inside buildReactData) and reloads so the cleared style drops from chrome.
describe('TheCatwalk — clear custom style via API (#4401)', () => {
  it('POSTs to /api/customstyle/clear and reloads when clearing a custom style', async () => {
    const reloadMock = jest.fn()
    const savedLocation = window.location
    delete window.location
    window.location = { reload: reloadMock }
    const fetchMock = (global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ success: 1, message: 'Your custom theme has been cleared.' }),
    }))
    try {
      const data = {
        type: 'the_catwalk', stylesheets: [], current_style: null, has_custom_style: 1,
        pagination: { offset: 0, limit: 100, total: 0 }, sort_options: [], current_sort: '0', filter: {},
      }
      const { getByRole } = render(<TheCatwalk data={data} user={{ guest: false }} />)
      fireEvent.click(getByRole('button', { name: /clear my custom style/i }))
      await waitFor(() =>
        expect(fetchMock).toHaveBeenCalledWith('/api/customstyle/clear', expect.objectContaining({ method: 'POST' }))
      )
      await waitFor(() => expect(reloadMock).toHaveBeenCalled())
    } finally {
      window.location = savedLocation
      delete global.fetch
    }
  })
})
