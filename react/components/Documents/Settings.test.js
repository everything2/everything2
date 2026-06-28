import React from 'react'
import { render } from '@testing-library/react'
import Settings from './Settings'
import fixture from '../../__fixtures__/pagestate/settings.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('Settings (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<Settings data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<Settings data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// #4390 contentData global dedup: the isEditor role flag is read from the global
// e2.user prop (user.editor) rather than a duplicated contentData key.
describe('Settings editor gating via user prop (#4390)', () => {
  // Drop the guest short-circuit from the captured fixture so the tab bar renders.
  const data = { ...fixture.contentData, error: undefined, currentUser: { node_id: 1, title: 'editoruser' } }

  it('shows the Admin tab when user.editor is true', () => {
    const { container } = render(
      <Settings data={data} e2={fixture} user={{ editor: true }} />
    )
    expect(container.textContent).toMatch(/admin/i)
  })
  it('hides the Admin tab when user.editor is false', () => {
    const { container } = render(
      <Settings data={data} e2={fixture} user={{ editor: false }} />
    )
    expect(container.textContent).not.toMatch(/admin/i)
  })
  it('does not crash when user is undefined', () => {
    const { container } = render(
      <Settings data={data} e2={fixture} user={undefined} />
    )
    expect(container.textContent).not.toMatch(/admin/i)
  })
})
