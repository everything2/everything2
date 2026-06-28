import React from 'react'
import { render } from '@testing-library/react'
import ShowUserVars from './ShowUserVars'
import fixture from '../../__fixtures__/pagestate/show_user_vars.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('ShowUserVars (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<ShowUserVars data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<ShowUserVars data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
  it('shows the admin username form when user.admin is true (#4390 user-prop gating)', () => {
    const data = { ...fixture.contentData, access_denied: 0, viewvars_mode: false, inspect_user: { node_id: 1, title: 'root' }, vars_data: [], user_data: [] }
    const { container } = render(<ShowUserVars data={data} user={{ admin: true }} />)
    expect(container.querySelector('input[name="username"]')).toBeTruthy()
    expect(container.textContent).toContain('Showing user variables for')
  })
  it('hides the admin form for a non-admin viewer', () => {
    const data = { ...fixture.contentData, access_denied: 0, viewvars_mode: false, inspect_user: { node_id: 1, title: 'root' }, vars_data: [], user_data: [] }
    const { container } = render(<ShowUserVars data={data} user={{ admin: false }} />)
    expect(container.querySelector('input[name="username"]')).toBeNull()
  })
  it('does not crash when the user prop is undefined (treated as non-admin)', () => {
    const data = { ...fixture.contentData, access_denied: 0, viewvars_mode: false, inspect_user: { node_id: 1, title: 'root' }, vars_data: [], user_data: [] }
    const { container } = render(<ShowUserVars data={data} user={undefined} />)
    expect(container.textContent).toContain('Show User Vars')
    expect(container.querySelector('input[name="username"]')).toBeNull()
  })
})
