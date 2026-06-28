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

// #4399 contentData identity dedup: the viewer's own identity (node_id/title) is read
// from the global e2.user prop, NOT from a duplicated data.currentUser key. The Perl
// page no longer emits currentUser, so a stale data.currentUser must be ignored.
describe('Settings viewer identity via user prop (#4399)', () => {
  const data = { ...fixture.contentData, error: undefined, currentUser: undefined }

  it('renders the viewer username from the user prop', () => {
    const { container } = render(
      <Settings data={data} e2={fixture} user={{ node_id: 12345, title: 'viewerself' }} />
    )
    // SettingsNavigation only renders the View Profile link when a username is present,
    // and links to /user/<username> built from the viewer's own title.
    const profileLink = container.querySelector('a[href="/user/viewerself"]')
    expect(profileLink).not.toBeNull()
    expect(profileLink.textContent).toMatch(/view profile/i)
  })

  it('does not render a profile link when there is no viewer identity', () => {
    const { container } = render(
      <Settings data={data} e2={fixture} user={undefined} />
    )
    expect(container.querySelector('a[href^="/user/"]')).toBeNull()
  })
})
