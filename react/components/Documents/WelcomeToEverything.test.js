import React from 'react'
import { render } from '@testing-library/react'
import WelcomeToEverything from './WelcomeToEverything'
import fixture from '../../__fixtures__/pagestate/welcome_to_everything.json'

// "Fixtures that match": render the Document view against the REAL, normalized
// /api/pagestate payload (captured by tools/capture-pagestate-fixtures.sh), so the
// component is exercised against the exact contract the server now emits --
// correctly-typed, integer node_ids (#4152/#4108). A component that relied on the old
// string types would fail here. This is the template for the component-by-component
// coverage: import the matching fixture, render, assert it mounts + keys are stable.
describe('WelcomeToEverything (against the real normalized pagestate fixture)', () => {
  it('renders the welcome view from the captured payload', () => {
    const { container } = render(
      <WelcomeToEverything data={fixture.contentData} e2={fixture} />
    )
    expect(container.textContent).toMatch(/collection of user-submitted writings/i)
  })

  it('pins the #4152 contract: the fixture has integer node_ids, never strings', () => {
    const blob = JSON.stringify(fixture)
    expect(blob.match(/"node_id":"\d/g)).toBeNull()            // no string ids
    expect((blob.match(/"node_id":\d/g) || []).length).toBeGreaterThan(0) // real ints present
  })

  it('renders node-keyed lists with no React "key" warnings (int keys are stable)', () => {
    const errors = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errors.push(a.join(' ')))
    render(<WelcomeToEverything data={fixture.contentData} e2={fixture} />)
    spy.mockRestore()
    const keyWarnings = errors.filter((e) => /unique "key"|each child in a list/i.test(e))
    expect(keyWarnings).toEqual([])
  })
})
