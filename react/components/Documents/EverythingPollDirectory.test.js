import React from 'react'
import { render } from '@testing-library/react'
import EverythingPollDirectory from './EverythingPollDirectory'
import fixture from '../../__fixtures__/pagestate/everything_poll_directory.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('EverythingPollDirectory (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<EverythingPollDirectory data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<EverythingPollDirectory data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// #4390: viewer admin status reads from the global `user` prop, NOT from page
// contentData (which used to re-emit is_admin -- the same bytes shipped twice).
describe('EverythingPollDirectory — admin gating from the user prop (#4390)', () => {
  it('shows the admin-only "Show old polls" toggle when user.admin is true', () => {
    const { container } = render(<EverythingPollDirectory user={{ admin: true }} />)
    expect(container.textContent).toMatch(/show old polls/i)
  })

  it('hides the admin-only toggle when user.admin is false', () => {
    const { container } = render(<EverythingPollDirectory user={{ admin: false }} />)
    expect(container.textContent).not.toMatch(/show old polls/i)
  })

  it('treats a missing user prop as non-admin (no admin toggle, no crash)', () => {
    const { container } = render(<EverythingPollDirectory user={undefined} />)
    expect(container.textContent).not.toMatch(/show old polls/i)
  })
})
