import React from 'react'
import { render, screen } from '@testing-library/react'
import ForReview from './ForReview'

// LinkNode mock surfaces the props so we can confirm correct id-alias usage
// (the bug: passing `node_id` instead of `nodeId` makes LinkNode render an
// empty/title-only link rather than the intended /node/<id> form).
jest.mock('../LinkNode', () => {
  return function MockLinkNode({ nodeId, title, type }) {
    return (
      <a
        data-testid="linknode"
        data-node-id={nodeId == null ? '' : String(nodeId)}
        data-type={type || ''}
      >
        {title || `node_id:${nodeId || 'none'}`}
      </a>
    )
  }
})

jest.mock('../NodeletContainer', () => {
  return function MockNodeletContainer({ children, title }) {
    return <div data-testid="container" data-title={title}>{children}</div>
  }
})

describe('ForReview nodelet', () => {
  const baseProps = {
    id: 'for_review',
    showNodelet: jest.fn(),
    nodeletIsOpen: true,
  }

  it('renders nothing for non-editors', () => {
    const { container } = render(
      <ForReview {...baseProps} forReviewData={{ isEditor: 0, drafts: [] }} />
    )
    expect(container).toBeEmptyDOMElement()
  })

  it('shows an empty-state message when there are no drafts', () => {
    render(
      <ForReview {...baseProps} forReviewData={{ isEditor: 1, drafts: [] }} />
    )
    expect(screen.getByText(/no drafts awaiting review/i)).toBeInTheDocument()
  })

  it('renders the draft title link via nodeId (not node_id) so the URL gets the integer', () => {
    render(
      <ForReview {...baseProps} forReviewData={{
        isEditor: 1,
        drafts: [{ node_id: 4242, title: 'draft title', author_user: 100, author_title: 'someuser', notecount: 0 }]
      }} />
    )
    const titleLink = screen.getByText('draft title')
    expect(titleLink).toHaveAttribute('data-node-id', '4242')
  })

  it('renders the author name and links it to the user node', () => {
    render(
      <ForReview {...baseProps} forReviewData={{
        isEditor: 1,
        drafts: [{ node_id: 4242, title: 'draft title', author_user: 100, author_title: 'someuser', notecount: 0 }]
      }} />
    )
    expect(screen.getByText('someuser')).toBeInTheDocument()
    const authorLink = screen.getByText('someuser')
    expect(authorLink).toHaveAttribute('data-node-id', '100')
    expect(authorLink).toHaveAttribute('data-type', 'user')
  })

  it('falls back to a bare LinkNode when author_title is missing (defense for stale data)', () => {
    render(
      <ForReview {...baseProps} forReviewData={{
        isEditor: 1,
        drafts: [{ node_id: 4242, title: 'draft title', author_user: 100, notecount: 0 }]
      }} />
    )
    // The fallback LinkNode receives nodeId but no title — the mock prints
    // `node_id:100` so the test confirms it surfaced a link, not a blank.
    expect(screen.getByText('node_id:100')).toBeInTheDocument()
  })

  it('renders the notecount link with latestnote in the tooltip', () => {
    render(
      <ForReview {...baseProps} forReviewData={{
        isEditor: 1,
        drafts: [{
          node_id: 4242, title: 'draft title', author_user: 100, author_title: 'someuser',
          notecount: 3, latestnote: '2026-05-29 10:00:00: looks good'
        }]
      }} />
    )
    const noteLink = screen.getByText('3')
    expect(noteLink).toHaveAttribute('title', expect.stringContaining('3 notes'))
    expect(noteLink).toHaveAttribute('title', expect.stringContaining('looks good'))
  })
})
