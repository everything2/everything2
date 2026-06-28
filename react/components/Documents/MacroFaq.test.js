import React from 'react'
import { render } from '@testing-library/react'
import MacroFaq from './MacroFaq'
import fixture from '../../__fixtures__/pagestate/macro_faq.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('MacroFaq (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<MacroFaq data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<MacroFaq data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

describe('MacroFaq (viewer flags from e2.user, #4390)', () => {
  const data = { username: 'someuser', userMacros: [], contentEditorsId: 0, godsId: 0 }

  it('guest viewer: shows login prompt, shows not-allowed notice', () => {
    const { container } = render(<MacroFaq data={data} user={{ guest: true, editor: false }} />)
    expect(container.textContent).toContain('Log in to see your macros.')
    expect(container.textContent).toContain('you are not allowed to use macros yet')
  })

  it('editor viewer: no login prompt, no not-allowed notice', () => {
    const { container } = render(<MacroFaq data={data} user={{ guest: false, editor: true }} />)
    expect(container.textContent).not.toContain('Log in to see your macros.')
    expect(container.textContent).not.toContain('you are not allowed to use macros yet')
  })

  it('undefined user does not crash (treated as non-guest, non-editor)', () => {
    const { container } = render(<MacroFaq data={data} user={undefined} />)
    expect(container.textContent).toContain('Macro FAQ')
    // non-editor -> not-allowed notice shown; non-guest -> no login prompt
    expect(container.textContent).toContain('you are not allowed to use macros yet')
    expect(container.textContent).not.toContain('Log in to see your macros.')
  })
})
