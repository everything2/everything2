import React from 'react'
import { render, screen } from '@testing-library/react'
import PageHeader from './PageHeader'

jest.mock('../LinkNode', () => {
  return function MockLinkNode({ id, display }) {
    return <a href={`/node/${id}`}>{display}</a>
  }
})

const node = { node_id: 10, title: 'Some e2node', type: 'e2node' }
const pageheader = { createdby: { node_id: 20, title: 'the creator', createtime: '2026-11-22 10:00:00' } }

describe('PageHeader', () => {
  it('shows the title', () => {
    render(<PageHeader node={node} pageheader={{}} />)
    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('Some e2node')
  })

  describe('who created an e2node (hideauthore2node, #4733)', () => {
    it('shows "created by" with a link to the creator', () => {
      const { container } = render(<PageHeader node={node} pageheader={pageheader} />)
      expect(container.querySelector('.page-header__createdby')).toHaveTextContent('created by the creator')
      expect(screen.getByRole('link', { name: 'the creator' })).toHaveAttribute('href', '/node/20')
    })

    it('leaves it out when the viewer has chosen to hide it', () => {
      const { container } = render(<PageHeader node={node} pageheader={pageheader} hideCreatedBy />)
      expect(container.querySelector('.page-header__createdby')).toBeNull()
      expect(screen.queryByText(/created by/)).toBeNull()
      expect(screen.queryByRole('link', { name: 'the creator' })).toBeNull()
      expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('Some e2node')
    })

    it('shows nothing when there is no creator to show', () => {
      const { container } = render(<PageHeader node={node} pageheader={{}} />)
      expect(container.querySelector('.page-header__createdby')).toBeNull()
    })
  })
})
