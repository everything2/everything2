import React from 'react'
import { render } from '@testing-library/react'
import DraftsForReview from './DraftsForReview'
import fixture from '../../__fixtures__/pagestate/drafts_for_review.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('DraftsForReview (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<DraftsForReview data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<DraftsForReview data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// #4390: editor-only Notes column is gated off the global e2.user prop, not a
// duplicated contentData flag.
describe('DraftsForReview editor gating (e2.user prop, #4390)', () => {
  const data = {
    type: 'drafts_for_review',
    drafts: [
      {
        title: 'A pending draft',
        author: 'normaluser1',
        author_id: 12345,
        publishtime: '2026-06-01 12:00:00',
        notecount: 3,
        latestnote: '2026-06-02: needs work'
      }
    ]
  }

  it('renders the Notes column for an editor (user.editor true)', () => {
    const { container } = render(<DraftsForReview data={data} user={{ editor: true }} />)
    expect(container.textContent).toContain('Notes')
    // editor-only notecount link is shown
    expect(container.textContent).toContain('3')
  })

  it('hides the Notes column for a non-editor (user.editor false)', () => {
    const { container } = render(<DraftsForReview data={data} user={{ editor: false }} />)
    expect(container.textContent).not.toContain('Notes')
    expect(container.textContent).toContain('A pending draft')
  })

  it('does not crash when user prop is undefined', () => {
    const { container } = render(<DraftsForReview data={data} user={undefined} />)
    expect(container.textContent).toContain('A pending draft')
    expect(container.textContent).not.toContain('Notes')
  })
})
