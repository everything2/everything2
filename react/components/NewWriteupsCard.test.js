import React from 'react'
import { render, screen } from '@testing-library/react'
import NewWriteupsCard from './NewWriteupsCard'

describe('NewWriteupsCard', () => {
  const writeupWithParentAndAuthor = {
    node_id: 999,
    title: 'good poetry by root',
    parent: { node_id: 100, title: 'good poetry' },
    author: { node_id: 1, title: 'root' },
    writeuptype: 'review',
  }

  const writeupWithoutParent = {
    node_id: 888,
    title: 'standalone node',
    parent: null,
    author: { node_id: 1, title: 'root' },
    writeuptype: 'document',
  }

  it('renders nothing when given an empty writeups array', () => {
    const { container } = render(<NewWriteupsCard writeups={[]} />)
    expect(container.firstChild).toBeNull()
  })

  it('renders the card header', () => {
    render(<NewWriteupsCard writeups={[writeupWithParentAndAuthor]} />)
    expect(screen.getByText('New Writeups')).toBeInTheDocument()
  })

  it('links the writeup title to the e2node with the author-name anchor (issue #4048)', () => {
    // Delegated to WriteupEntry → LinkNode. LinkNode only URL-encodes specific
    // chars (&@+/;?), so spaces in titles render unencoded — browsers accept
    // that in href values. The author-name anchor is the key fix here.
    render(<NewWriteupsCard writeups={[writeupWithParentAndAuthor]} />)
    const titleLink = screen.getByText('good poetry')
    expect(titleLink.tagName).toBe('A')
    expect(titleLink.getAttribute('href')).toBe('/title/good poetry?author_id=1#root')
  })

  it('renders the writeup type as a link to the writeup-specific URL (issue #4048)', () => {
    // WriteupEntry renders the type as <LinkNode type="writeup" author="root" title="good poetry" display="review" />
    // which produces /user/<author>/writeups/<title> — the canonical URL for a
    // specific writeup, even better than the in-page anchor.
    render(<NewWriteupsCard writeups={[writeupWithParentAndAuthor]} />)
    const typeLink = screen.getByText('review')
    expect(typeLink.tagName).toBe('A')
    expect(typeLink.getAttribute('href')).toBe('/user/root/writeups/good poetry')
  })

  it('links the author byline to the user profile', () => {
    render(<NewWriteupsCard writeups={[writeupWithParentAndAuthor]} />)
    const authorLink = screen.getByText('root')
    expect(authorLink.tagName).toBe('A')
    expect(authorLink.getAttribute('href')).toBe('/user/root')
  })

  it('uses title-based URL when entry has no parent (no anchor needed)', () => {
    // No parent → WriteupEntry's "node title directly" branch. LinkNode receives
    // only `nodeId` (destructured but not used for URL building) and `title`,
    // so it falls through to `/title/<title>` with no anchor or author param.
    render(<NewWriteupsCard writeups={[writeupWithoutParent]} />)
    const titleLink = screen.getByText('standalone node')
    expect(titleLink.tagName).toBe('A')
    expect(titleLink.getAttribute('href')).toBe('/title/standalone node')
  })

  it('respects the limit prop', () => {
    const writeups = Array.from({ length: 15 }, (_, i) => ({
      ...writeupWithParentAndAuthor,
      node_id: i,
      parent: { ...writeupWithParentAndAuthor.parent, title: `node ${i}` },
    }))
    render(<NewWriteupsCard writeups={writeups} limit={3} />)
    expect(screen.getAllByText(/^node \d+$/)).toHaveLength(3)
  })

  it('uses mobile class when isMobile is true', () => {
    const { container } = render(<NewWriteupsCard writeups={[writeupWithParentAndAuthor]} isMobile={true} />)
    expect(container.querySelector('.new-writeups-card--mobile')).toBeTruthy()
  })

  it('renders a "more writeups" link to Writeups By Type', () => {
    render(<NewWriteupsCard writeups={[writeupWithParentAndAuthor]} />)
    const moreLink = screen.getByText('more writeups')
    expect(moreLink.tagName).toBe('A')
    expect(moreLink.getAttribute('href')).toContain('/node/superdoc/Writeups')
  })
})
