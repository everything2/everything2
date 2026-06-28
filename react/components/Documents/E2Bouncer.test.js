import React from 'react'
import { render } from '@testing-library/react'
import E2Bouncer from './E2Bouncer'
import fixture from '../../__fixtures__/pagestate/e2_bouncer.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('E2Bouncer (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<E2Bouncer data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<E2Bouncer data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

describe('E2Bouncer chanop gating (user prop, #4390)', () => {
  it('renders the bouncer form for a chanop (user.chanop true)', () => {
    const { container } = render(<E2Bouncer data={fixture.contentData} e2={fixture} user={{ chanop: true }} />)
    expect(container.textContent).toContain('Nerf Borg')
    expect(container.textContent).not.toContain('Permission Denied')
  })
  it('shows Permission Denied for a non-chanop (user.chanop false)', () => {
    const { container } = render(<E2Bouncer data={fixture.contentData} e2={fixture} user={{ chanop: false }} />)
    expect(container.textContent).toContain('Permission Denied')
    expect(container.textContent).toContain('Channel Operators')
  })
  it('does not crash and denies access when user prop is undefined', () => {
    const { container } = render(<E2Bouncer data={fixture.contentData} e2={fixture} user={undefined} />)
    expect(container.textContent).toContain('Permission Denied')
  })
})
