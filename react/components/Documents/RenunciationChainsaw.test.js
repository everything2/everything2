import React from 'react'
import { render } from '@testing-library/react'
import RenunciationChainsaw from './RenunciationChainsaw'
import fixture from '../../__fixtures__/pagestate/renunciation_chainsaw.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('RenunciationChainsaw (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<RenunciationChainsaw data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('node_id is read from the e2 prop (global dedup #4399)', () => {
    const e2 = { ...fixture, node: { ...fixture.node, node_id: 987654 } }
    const { container } = render(<RenunciationChainsaw data={{ type: 'renunciation_chainsaw' }} e2={e2} user={fixture.user || {}} />)
    expect(container.textContent).toContain('Generate nodelist')
    expect(container.querySelector('form').getAttribute('action')).toBe('/?node_id=987654')
    expect(container.querySelector('input[name="node_id"]').getAttribute('value')).toBe('987654')
  })
  it('back-link node_id (in textContent) comes from the e2 prop after processing (#4399)', () => {
    const e2 = { ...fixture, node: { ...fixture.node, node_id: 987654 } }
    const data = {
      type: 'renunciation_chainsaw',
      processed: 1,
      from_user: { id: 1, title: 'alice' },
      to_user: { id: 2, title: 'bob' },
      reparented: [{ node_id: 42, title: 'foo' }]
    }
    const { container } = render(<RenunciationChainsaw data={data} e2={e2} user={fixture.user || {}} />)
    expect(container.textContent).toContain('back')
    expect(container.querySelector('.renunciation-chainsaw__back-link a').getAttribute('href')).toContain('987654')
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<RenunciationChainsaw data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})
