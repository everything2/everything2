import React from 'react'
import { render } from '@testing-library/react'
import NodeForbiddance from './NodeForbiddance'
import fixture from '../../__fixtures__/pagestate/node_forbiddance.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('NodeForbiddance (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<NodeForbiddance data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('reads node_id from the e2 prop (global dedup #4399)', () => {
    const data = { message: '', forbidden_users: [{ user_id: 7, user_title: 'victim', forbidder_id: 9, forbidder_title: 'forbidder', reason: '' }] }
    const { container } = render(<NodeForbiddance data={data} e2={{ node: { node_id: 555 } }} user={{}} />)
    expect(container.textContent).toBeTruthy()
    expect(container.querySelector('input[name="node_id"]').value).toBe('555')
    expect(container.querySelector('a.node-forbiddance__link').getAttribute('href')).toContain('node_id=555')
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<NodeForbiddance data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})
