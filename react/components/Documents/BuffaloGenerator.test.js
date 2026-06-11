import React from 'react'
import { render } from '@testing-library/react'
import BuffaloGenerator from './BuffaloGenerator'
import regularFixture from '../../__fixtures__/pagestate/buffalo_generator.json'
import haikuFixture from '../../__fixtures__/pagestate/buffalo_haiku_generator.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payloads,
// pinning the int-typed contract (#4152/#4108). One component serves both the buffalo_generator
// and buffalo_haiku_generator document types.
describe('BuffaloGenerator (real pagestate fixtures)', () => {
  it('mounts against the buffalo_generator payload', () => {
    const { container } = render(<BuffaloGenerator data={regularFixture.contentData} e2={regularFixture} user={regularFixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('mounts against the buffalo_haiku_generator payload', () => {
    const { container } = render(<BuffaloGenerator data={haikuFixture.contentData} e2={haikuFixture} user={haikuFixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixtures have integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(regularFixture).match(/"node_id":"\d/g)).toBeNull()
    expect(JSON.stringify(haikuFixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<BuffaloGenerator data={regularFixture.contentData} e2={regularFixture} user={regularFixture.user || {}} />)
    render(<BuffaloGenerator data={haikuFixture.contentData} e2={haikuFixture} user={haikuFixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})
