import React from 'react'
import { render } from '@testing-library/react'
import TheNodeCrypt from './TheNodeCrypt'
import fixture from '../../__fixtures__/pagestate/the_node_crypt.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('TheNodeCrypt (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<TheNodeCrypt data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<TheNodeCrypt data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

describe('TheNodeCrypt coffin view (#4717)', () => {
  const coffin = (extra) => ({
    viewing_coffin: 1,
    node_id: 10,
    coffin_id: 2055267,
    is_resurrected: 0,
    lab_id: 20,
    fields: [{ key: 'title', value: 'An old test document', is_node_id: 0 }],
    field_count: 1,
    ...extra,
  })

  it('offers RESURRECT for a copy that can come back', () => {
    const { getByText, container } = render(<TheNodeCrypt data={coffin({ resurrect_refusal: null })} />)
    expect(getByText('RESURRECT').getAttribute('href')).toBe('/?node_id=20&olde2nodeid=2055267')
    expect(container.querySelector('.node-crypt__refusal')).toBeNull()
  })

  it('shows why in place of RESURRECT for a copy that cannot', () => {
    const { queryByText, container } = render(
      <TheNodeCrypt data={coffin({ resurrect_refusal: 'Its type, restricted_testdoc, no longer exists.' })} />
    )
    expect(queryByText('RESURRECT')).toBeNull()
    expect(container.querySelector('.node-crypt__refusal').textContent).toBe(
      "This node can't be resurrected. Its type, restricted_testdoc, no longer exists."
    )
    expect(queryByText('An old test document')).not.toBeNull()
  })
})
