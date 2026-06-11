import React from 'react'
import { render } from '@testing-library/react'
import TheKillingFloor from './TheKillingFloor'
import fixture from '../../__fixtures__/pagestate/the_killing_floor_ii.json'
import fixtureKillingFloor from '../../__fixtures__/pagestate/the_killing_floor.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('TheKillingFloor (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<TheKillingFloor data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<TheKillingFloor data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

describe('TheKillingFloor (the_killing_floor fixture, #4255)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<TheKillingFloor data={fixtureKillingFloor.contentData} e2={fixtureKillingFloor} user={fixtureKillingFloor.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixtureKillingFloor).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<TheKillingFloor data={fixtureKillingFloor.contentData} e2={fixtureKillingFloor} user={fixtureKillingFloor.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})
