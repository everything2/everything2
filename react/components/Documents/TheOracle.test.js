import React from 'react'
import { render } from '@testing-library/react'
import TheOracle from './TheOracle'
import fixture from '../../__fixtures__/pagestate/the_oracle.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('TheOracle (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<TheOracle data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<TheOracle data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// Role flags now come from the global e2.user prop, not contentData (#4390)
describe('TheOracle role gating via user prop', () => {
  const searchData = {
    type: 'the_oracle',
    classic_mode: 0,
    search_result: {
      username: 'someuser',
      user_id: 123,
      vars: [{ key: 'easter_eggs', value: '5' }]
    }
  }

  it('admin viewer (user.admin) sees the per-var edit link', () => {
    const { container } = render(<TheOracle data={searchData} user={{ admin: true }} />)
    expect(container.textContent).toContain('edit')
  })

  it('non-admin viewer (user.admin false) does not see the edit link', () => {
    const { container } = render(<TheOracle data={searchData} user={{ admin: false }} />)
    expect(container.textContent).not.toContain('edit')
  })

  it('missing user prop does not crash and hides admin controls', () => {
    const { container } = render(<TheOracle data={searchData} user={undefined} />)
    expect(container.textContent).toContain('someuser')
    expect(container.textContent).not.toContain('edit')
  })
})
