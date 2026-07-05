import React from 'react'
import { render, screen } from '@testing-library/react'
import UnimplementedPage from './UnimplementedPage'

// UnimplementedPage is the fallback shown when a node's htmlpage has not been
// migrated to React. It's pure/prop-driven -- it echoes the node/page identity
// and builds a prefilled GitHub "new issue" link. No fixture needed.
describe('UnimplementedPage', () => {
  const contentData = {
    node: { title: 'Some Old Node', type: 'superdoc' },
    page: { title: 'weird display page' },
  }

  it('renders the node, type, and page identity', () => {
    render(<UnimplementedPage contentData={contentData} />)
    expect(screen.getByText('Some Old Node')).toBeInTheDocument()
    expect(screen.getByText('superdoc')).toBeInTheDocument()
    // page title appears both in the <code> and the definition list
    expect(screen.getAllByText('weird display page').length).toBeGreaterThan(0)
  })

  it('builds a GitHub issue link with the page title encoded into the query', () => {
    render(<UnimplementedPage contentData={contentData} />)
    const link = screen.getByRole('link', { name: /report this issue on github/i })
    const href = link.getAttribute('href')
    expect(href).toContain('github.com/everything2/everything2/issues/new')
    // title/body are URI-encoded -> spaces become %20, never raw
    expect(href).toContain(encodeURIComponent('Unimplemented page: weird display page'))
    expect(href).not.toMatch(/title=Unimplemented page:/)
    expect(link).toHaveAttribute('target', '_blank')
    expect(link).toHaveAttribute('rel', expect.stringContaining('noopener'))
  })

  it('degrades gracefully when contentData is missing', () => {
    const { container } = render(<UnimplementedPage />)
    // no throw; still offers the homepage escape hatch
    expect(container).toBeTruthy()
    expect(screen.getByRole('link', { name: /return to everything2 homepage/i })).toBeInTheDocument()
  })
})
