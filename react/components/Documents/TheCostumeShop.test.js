import React from 'react'
import { render } from '@testing-library/react'
import TheCostumeShop from './TheCostumeShop'
import fixture from '../../__fixtures__/pagestate/the_costume_shop.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('TheCostumeShop (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<TheCostumeShop data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<TheCostumeShop data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// #4390: viewer identity (admin, gp) reads from the global `user` prop, NOT from page
// contentData (which used to re-emit isAdmin/userGP -- the same bytes shipped twice).
describe('TheCostumeShop — viewer identity from the user prop (#4390)', () => {
  const openShop = {
    isHalloween: true, costumeCost: 0, currentCostume: '', hasCostume: false, canAfford: true,
  }

  it('gates the admin note on user.admin and prints user.gp (not contentData)', () => {
    const { container, rerender } = render(
      <TheCostumeShop data={{ costumeShop: openShop }} user={{ admin: true, gp: 42 }} />
    )
    expect(container.textContent).toMatch(/you are an administrator/i)  // user.admin -> note shown
    expect(container.textContent).toContain('Your GP: 42')              // user.gp, not data.userGP

    rerender(<TheCostumeShop data={{ costumeShop: openShop }} user={{ admin: false, gp: 42 }} />)
    expect(container.textContent).not.toMatch(/you are an administrator/i)  // non-admin -> hidden
    expect(container.textContent).toContain('Your GP: 42')
  })

  it('treats a missing user prop as non-admin, GP 0 (no crash)', () => {
    const cantAfford = { ...openShop, costumeCost: 30, canAfford: false }
    const { container } = render(<TheCostumeShop data={{ costumeShop: cantAfford }} user={undefined} />)
    expect(container.textContent).toContain('Your GP: 0')
    expect(container.textContent).not.toMatch(/you are an administrator/i)
  })
})
