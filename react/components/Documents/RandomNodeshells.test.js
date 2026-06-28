import React from 'react'
import { render } from '@testing-library/react'
import RandomNodeshells from './RandomNodeshells'
import fixture from '../../__fixtures__/pagestate/random_nodeshells.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('RandomNodeshells (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<RandomNodeshells data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<RandomNodeshells data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

describe('RandomNodeshells guest gating (#4390, e2.user-driven)', () => {
  const guestData = { type: 'random_nodeshells', message: 'If you logged in, you could see random nodeshells.' }
  const memberData = { type: 'random_nodeshells', num_searched: 1200, num_found: 0, nodeshells: [] }

  it('guest viewer (user.guest===true) shows the login-gated message', () => {
    const { container } = render(<RandomNodeshells data={guestData} user={{ guest: true }} />)
    expect(container.textContent).toContain('If you logged in')
    expect(container.textContent).not.toContain('How this works')
  })
  it('member viewer (user.guest===false) shows the nodeshell generator, not the gate', () => {
    const { container } = render(<RandomNodeshells data={memberData} user={{ guest: false }} />)
    expect(container.textContent).toContain('How this works')
    expect(container.textContent).not.toContain('If you logged in')
  })
  it('missing user prop does not crash and renders as non-guest', () => {
    const { container } = render(<RandomNodeshells data={memberData} user={undefined} />)
    expect(container.textContent).toContain('How this works')
  })
})
