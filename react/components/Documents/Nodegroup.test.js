import React from 'react'
import { render } from '@testing-library/react'
import Nodegroup from './Nodegroup'
import fixture from '../../__fixtures__/pagestate/nodegroup.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload.
describe('Nodegroup (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<Nodegroup data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<Nodegroup data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// #4617: renderE2Content returns { html, ... }, so the description must use its .html.
describe('Nodegroup description', () => {
  const withDescription = (doctext) => ({
    ...fixture.contentData,
    nodegroup: { ...fixture.contentData.nodegroup, doctext },
  })

  it('renders the description as HTML, with its E2 links', () => {
    const { container } = render(
      <Nodegroup data={withDescription('<p>Nodes about <em>cheese</em>, see [Everything2].</p>')} e2={fixture} user={fixture.user || {}} />
    )
    const description = container.querySelector('.nodegroup__description')
    expect(description).not.toBeNull()
    expect(description.textContent).not.toContain('[object Object]')
    expect(description.querySelector('em').textContent).toBe('cheese')
    expect(description.querySelector('a').textContent).toBe('Everything2')
  })

  it('renders no description block when there is no description', () => {
    const { container } = render(<Nodegroup data={withDescription('')} e2={fixture} user={fixture.user || {}} />)
    expect(container.querySelector('.nodegroup__description')).toBeNull()
  })
})
