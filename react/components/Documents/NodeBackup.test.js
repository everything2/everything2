import React from 'react'
import { render } from '@testing-library/react'
import NodeBackup from './NodeBackup'
import fixture from '../../__fixtures__/pagestate/node_backup.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('NodeBackup (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<NodeBackup data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<NodeBackup data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
  // Role-gating: the "For noder (admin only)" field renders only for user.admin.
  // The form (and thus the field) only renders when not in the dev environment.
  const prodData = { ...fixture.contentData, isDevelopment: false }
  it('shows the admin-only "For noder" field for admins (user.admin)', () => {
    const { container } = render(<NodeBackup data={prodData} user={{ admin: true }} />)
    expect(container.textContent).toContain('(admin only)')
  })
  it('hides the admin-only "For noder" field for non-admins', () => {
    const { container } = render(<NodeBackup data={prodData} user={{ admin: false }} />)
    expect(container.textContent).not.toContain('(admin only)')
  })
  it('does not crash when user is undefined', () => {
    const { container } = render(<NodeBackup data={prodData} user={undefined} />)
    expect(container.textContent).not.toContain('(admin only)')
  })
})
