import React from 'react'
import { render, fireEvent, waitFor } from '@testing-library/react'
import ThemeNirvana from './ThemeNirvana'
import fixture from '../../__fixtures__/pagestate/theme_nirvana.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('ThemeNirvana (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<ThemeNirvana data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<ThemeNirvana data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })

  // #4390 contentData-global-dedup: is_guest now read from the global `user` prop
  // (user.guest), not a duplicated contentData key. The "[ test ]" link is the
  // guest-gated element — hidden for guests, shown for logged-in viewers.
  it('shows the [ test ] link for a logged-in (non-guest) viewer', () => {
    const { container } = render(
      <ThemeNirvana data={fixture.contentData} user={{ guest: false }} />
    )
    expect(container.textContent).toContain('[ test ]')
  })
  it('hides the [ test ] link for a guest viewer', () => {
    const { container } = render(
      <ThemeNirvana data={fixture.contentData} user={{ guest: true }} />
    )
    expect(container.textContent).not.toContain('[ test ]')
  })
  it('does not crash when the user prop is undefined (treated as non-guest)', () => {
    const { container } = render(
      <ThemeNirvana data={fixture.contentData} user={undefined} />
    )
    expect(container).toBeTruthy()
    expect(container.textContent).toContain('[ test ]')
  })

  // #4401: clearing a custom style POSTs to /api/customstyle/clear (was a ?clearVandalism
  // GET that mutated VARS inside buildReactData) and reloads so the cleared style drops.
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
      const { getByRole } = render(
        <ThemeNirvana data={{ has_custom_style: 1, stylesheets: [], current_style: null }} user={{ guest: false }} />
      )
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
