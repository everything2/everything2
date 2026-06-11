import React from 'react'
import { render } from '@testing-library/react'
import DebatecommentEdit from './DebatecommentEdit'
import editFixture from '../../__fixtures__/pagestate/debatecommentEdit.json'
import replytoFixture from '../../__fixtures__/pagestate/debatecommentReplyto.json'

// Fixture-backed coverage (PageState 2a, #4255): DebatecommentEdit serves BOTH the
// `debatecommentEdit` (edit) and `debatecommentReplyto` (reply) views, so it's exercised
// against both real normalized /api/pagestate payloads (captured from a seeded debate
// node, tools/seeds.pl, as an authenticated request).
describe.each([
  ['debatecommentEdit', editFixture],
  ['debatecommentReplyto', replytoFixture],
])('DebatecommentEdit (%s real pagestate fixture)', (label, fixture) => {
  it('mounts against the captured payload', () => {
    const { container } = render(
      <DebatecommentEdit data={fixture.contentData} e2={fixture} user={fixture.user || {}} />
    )
    expect(container).toBeTruthy()
  })

  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })

  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<DebatecommentEdit data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})
