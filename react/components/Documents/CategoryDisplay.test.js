import React from 'react'
import { render } from '@testing-library/react'
import CategoryDisplay from './CategoryDisplay'
import fixture from '../../__fixtures__/pagestate/category.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload.
describe('CategoryDisplay (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<CategoryDisplay data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<CategoryDisplay data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})
