import React from 'react'
import { render } from '@testing-library/react'
import BadSpellingsListing from './BadSpellingsListing'
import fixture from '../../__fixtures__/pagestate/bad_spellings_listing.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('BadSpellingsListing (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<BadSpellingsListing data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<BadSpellingsListing data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
  it('reads role flags from the user prop (admin/editor gating)', () => {
    const yes = render(<BadSpellingsListing data={fixture.contentData} user={{ admin: true, editor: true }} />)
    expect(yes.container.textContent).toContain('Site administrators can edit this setting')
    expect(yes.container.textContent).toContain('total')

    const no = render(<BadSpellingsListing data={fixture.contentData} user={{ admin: false, editor: false }} />)
    expect(no.container.textContent).not.toContain('Site administrators can edit this setting')
    expect(no.container.textContent).not.toContain('total')
  })
  it('does not crash when the user prop is undefined', () => {
    const { container } = render(<BadSpellingsListing data={fixture.contentData} user={undefined} />)
    expect(container.textContent).not.toContain('Site administrators can edit this setting')
  })
})
