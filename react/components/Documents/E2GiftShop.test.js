import React from 'react'
import { render } from '@testing-library/react'
import E2GiftShop from './E2GiftShop'
import fixture from '../../__fixtures__/pagestate/e2_gift_shop.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('E2GiftShop (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<E2GiftShop data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<E2GiftShop data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// Editor gating via the global `user` prop (#4390 contentData dedup):
// `isEditor` is no longer carried in contentData; it is read from user.editor.
describe('E2GiftShop editor gating (user prop)', () => {
  it('shows the editor-only "free for editors" topic note when user.editor is true', () => {
    const { container } = render(
      <E2GiftShop data={fixture.contentData} user={{ editor: true }} />
    )
    expect(container.textContent).toContain('free for editors')
  })
  it('hides the editor-only topic note when user.editor is false', () => {
    const { container } = render(
      <E2GiftShop data={fixture.contentData} user={{ editor: false }} />
    )
    expect(container.textContent).not.toContain('free for editors')
  })
  it('does not crash when user is undefined', () => {
    const { container } = render(
      <E2GiftShop data={fixture.contentData} user={undefined} />
    )
    expect(container).toBeTruthy()
  })
})
