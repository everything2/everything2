import React from 'react'
import { render } from '@testing-library/react'
import DrNatesSecretLab from './DrNatesSecretLab'
import fixture from '../../__fixtures__/pagestate/dr_nate_s_secret_lab.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('DrNatesSecretLab (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<DrNatesSecretLab data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('renders the lab title', () => {
    const { getByText } = render(<DrNatesSecretLab data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(getByText("Dr. Nate's Secret Lab")).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<DrNatesSecretLab data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

describe('DrNatesSecretLab resurrecting', () => {
  const { fireEvent, screen, waitFor } = require('@testing-library/react')
  const resurrect = async (reply) => {
    global.fetch = jest.fn().mockResolvedValue({ json: () => Promise.resolve(reply) })
    render(<DrNatesSecretLab data={{}} />)
    fireEvent.change(screen.getByLabelText('Node ID to resurrect:'), { target: { value: '123' } })
    fireEvent.click(screen.getByRole('button', { name: 'Resurrect Node' }))
    await waitFor(() => expect(screen.getByText('Success!')).toBeTruthy())
  }
  afterEach(() => { delete global.fetch })

  it('tells the admin a resurrected account needs a password reset', async () => {
    await resurrect({ success: 1, message: 'Node 123 successfully resurrected from tomb', node_id: 123,
      title: 'someone', passwordResetNeeded: true, e2nodeAttached: false })
    expect(screen.getByText(/The account has no password/)).toBeTruthy()
    expect(screen.getByRole('link', { name: 'Reset password' }).getAttribute('href')).toBe('/title/Reset%20password')
  })

  it('says nothing about passwords for other nodes', async () => {
    await resurrect({ success: 1, message: 'Node 123 successfully resurrected from tomb', node_id: 123,
      title: 'a draft', passwordResetNeeded: false, e2nodeAttached: false })
    expect(screen.queryByText(/The account has no password/)).toBeNull()
  })
})
