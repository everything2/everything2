import React from 'react'
import { render } from '@testing-library/react'
import PermissionDenied from './PermissionDenied'
import fixture from '../../__fixtures__/pagestate/permission_denied.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('PermissionDenied (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<PermissionDenied data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<PermissionDenied data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// #4522: the message is owned by the component; the page ships only { type }.
describe('PermissionDenied message owned by the component', () => {
  it('renders the default message with no server-supplied copy', () => {
    const { container } = render(<PermissionDenied data={{ type: 'permission_denied' }} />)
    expect(container.textContent).toMatch(/don't have access to that node/i)
  })

  it('does not crash on empty data', () => {
    const { container } = render(<PermissionDenied data={{}} />)
    expect(container.textContent).toMatch(/don't have access to that node/i)
  })
})
