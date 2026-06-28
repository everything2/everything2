import React from 'react'
import { render } from '@testing-library/react'
import BetweenTheCracks from './BetweenTheCracks'
import fixture from '../../__fixtures__/pagestate/between_the_cracks.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('BetweenTheCracks (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<BetweenTheCracks data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<BetweenTheCracks data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

describe('BetweenTheCracks guest gating (#4390 user-prop)', () => {
  it('shows the guest message when user.guest is true', () => {
    const { container } = render(<BetweenTheCracks data={{}} user={{ guest: true }} />)
    expect(container.textContent).toMatch(/you fall between the cracks yourself/i)
  })
  it('does not show the guest message when user.guest is false', () => {
    const { container } = render(<BetweenTheCracks data={{}} user={{ guest: false }} />)
    expect(container.textContent).not.toMatch(/you fall between the cracks yourself/i)
    expect(container.textContent).toMatch(/fallen between the cracks/i)
  })
  it('does not crash when user is undefined', () => {
    const { container } = render(<BetweenTheCracks data={{}} user={undefined} />)
    expect(container).toBeTruthy()
    // undefined user => not guest => normal (non-guest) view renders
    expect(container.textContent).not.toMatch(/you fall between the cracks yourself/i)
  })
})
