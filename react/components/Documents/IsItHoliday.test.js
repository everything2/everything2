import React from 'react'
import { render } from '@testing-library/react'
import IsItHoliday from './IsItHoliday'
import christmasFixture from '../../__fixtures__/pagestate/is_it_christmas_yet.json'
import halloweenFixture from '../../__fixtures__/pagestate/is_it_halloween_yet.json'
import nydFixture from '../../__fixtures__/pagestate/is_it_new_year_s_day_yet.json'
import nyeFixture from '../../__fixtures__/pagestate/is_it_new_year_s_eve_yet.json'
import afdFixture from '../../__fixtures__/pagestate/is_it_april_fools_day_yet.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payloads,
// pinning the int-typed contract (#4152/#4108). IsItHoliday is rendered for several
// holiday documents that differ only in contentData.occasion, so each captured fixture
// is exercised here.
const cases = [
  ['is_it_christmas_yet', christmasFixture],
  ['is_it_halloween_yet', halloweenFixture],
  ['is_it_new_year_s_day_yet', nydFixture],
  ['is_it_new_year_s_eve_yet', nyeFixture],
  ['is_it_april_fools_day_yet', afdFixture]
]

describe.each(cases)('IsItHoliday (real pagestate fixture: %s)', (key, fixture) => {
  it('mounts against the captured payload', () => {
    const { container } = render(<IsItHoliday data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<IsItHoliday data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})
