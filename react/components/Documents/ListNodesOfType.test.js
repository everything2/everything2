import React from 'react'
import { render } from '@testing-library/react'
import ListNodesOfType from './ListNodesOfType'
import fixture from '../../__fixtures__/pagestate/gnl.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('ListNodesOfType (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<ListNodesOfType data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<ListNodesOfType data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
  it('reads the viewer node_id from the user prop, not contentData (#4399)', () => {
    // contentData no longer carries the viewer's own user_id; it comes from e2.user.
    expect(fixture.contentData.user_id).toBeUndefined()
    // Granted (non-denied) data so the viewer footer renders; node_id is sourced from the user prop.
    const grantedData = { type: 'list_nodes_of_type', access_denied: 0, node_types: [], default_type: '' }
    const { container } = render(
      <ListNodesOfType data={grantedData} e2={fixture} user={{ node_id: 424242 }} />
    )
    expect(container.textContent).toContain('424242')
  })
})
