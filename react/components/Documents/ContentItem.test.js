import React from 'react'
import { render, screen } from '@testing-library/react'
import ContentItem from './ContentItem'

// ContentItem is the shared content-snippet renderer used by front-page lists.
// It's prop-driven: the show* flags gate each fragment (title, byline, type,
// date, linkedby, content) and parent-vs-title decides the link target.
describe('ContentItem', () => {
  const base = {
    node_id: 42,
    title: 'A Writeup Title',
    author: { title: 'somebody', node_id: 7 },
    type: 'idea',
    content: 'Hello world',
    createtime: '2020-01-02 03:04:05',
  }

  it('renders nothing when there is no item', () => {
    const { container } = render(<ContentItem item={null} />)
    expect(container).toBeEmptyDOMElement()
  })

  it('shows the title as a link to the node when showTitle is set', () => {
    render(<ContentItem item={base} showTitle />)
    const link = screen.getByRole('link', { name: 'A Writeup Title' })
    expect(link).toHaveAttribute('href', '/node/42')
  })

  it('links to the parent e2node with an author anchor when a parent is present and showTitle is off', () => {
    const item = { ...base, parent: { title: 'Parent Node', node_id: 99 } }
    render(<ContentItem item={item} />)
    const link = screen.getByRole('link', { name: 'Parent Node' })
    expect(link.getAttribute('href')).toBe(`/node/99#${encodeURIComponent('somebody')}`)
  })

  it('shows the byline linking to the author when showByline is set', () => {
    render(<ContentItem item={base} showByline />)
    const author = screen.getByRole('link', { name: 'somebody' })
    expect(author).toHaveAttribute('href', '/user/somebody')
    expect(author).toHaveClass('author')
  })

  it('renders a "more" link only when the item is truncated', () => {
    const { rerender } = render(<ContentItem item={{ ...base, truncated: false }} />)
    expect(screen.queryByRole('link', { name: 'more' })).toBeNull()
    rerender(<ContentItem item={{ ...base, truncated: true }} />)
    expect(screen.getByRole('link', { name: 'more' })).toHaveAttribute('href', '/node/42')
  })

  it('shows a linkedby credit when showLinkedBy is set', () => {
    render(<ContentItem item={{ ...base, linkedby: 'linker' }} showLinkedBy />)
    expect(screen.getByText(/linked by/i)).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'linker' })).toHaveAttribute('href', '/user/linker')
  })
})
