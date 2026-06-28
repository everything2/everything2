import React from 'react'
import { render } from '@testing-library/react'
import MyRecentWriteups from './MyRecentWriteups'
import fixture from '../../__fixtures__/pagestate/my_recent_writeups.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('MyRecentWriteups (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<MyRecentWriteups data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<MyRecentWriteups data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
  it('sources the viewer identity link from the user prop, not contentData (#4399)', () => {
    const data = { type: 'my_recent_writeups', is_guest: 0, writeup_count: 3, one_year_ago: 'Monday, June 27, 2025' }
    const { container } = render(<MyRecentWriteups data={data} user={{ node_id: 12345, title: 'Viewer' }} />)
    expect(container.textContent).toContain('you have published')
    expect(container.querySelector('a.my-recent-writeups__link').getAttribute('href')).toBe('/?node_id=12345')
  })
})
