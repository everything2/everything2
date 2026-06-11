import React from 'react'
import { render } from '@testing-library/react'
import Chatterlight from './Chatterlight'
import chatterlight from '../../__fixtures__/pagestate/chatterlight.json'
import chatterlightClassic from '../../__fixtures__/pagestate/chatterlight_classic.json'
import chatterlighter from '../../__fixtures__/pagestate/chatterlighter.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payloads.
// Chatterlight.js backs three document types (chatterlight, chatterlight classic, chatterlighter);
// each captured fixture pins the int-typed contract (#4152/#4108).
describe.each([
  ['chatterlight', chatterlight],
  ['chatterlight_classic', chatterlightClassic],
  ['chatterlighter', chatterlighter],
])('Chatterlight (%s real pagestate fixture)', (key, fixture) => {
  it('mounts against the captured payload', () => {
    const { container } = render(<Chatterlight data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<Chatterlight data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})
