import React from 'react'
import { render } from '@testing-library/react'
import DisplayCategories from './DisplayCategories'
import fixture from '../../__fixtures__/pagestate/display_categories.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('DisplayCategories (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<DisplayCategories data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<DisplayCategories data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

describe('DisplayCategories guest gating (user.guest, #4390)', () => {
  it('hides the "Can I Contribute?" column for guests', () => {
    const { container } = render(
      <DisplayCategories data={fixture.contentData} user={{ guest: true }} />
    )
    expect(container.textContent).not.toContain('Can I Contribute?')
  })
  it('shows the "Can I Contribute?" column for non-guests', () => {
    const { container } = render(
      <DisplayCategories data={fixture.contentData} user={{ guest: false }} />
    )
    expect(container.textContent).toContain('Can I Contribute?')
  })
  it('does not crash with an undefined user prop', () => {
    const { container } = render(
      <DisplayCategories data={fixture.contentData} user={undefined} />
    )
    // No crash: optional chaining keeps !!user?.guest safe (=> false / non-guest).
    expect(container).toBeTruthy()
    expect(container.textContent).toContain('Category')
  })
})
