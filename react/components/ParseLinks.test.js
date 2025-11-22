import React from 'react'
import { render, screen } from '@testing-library/react'
import ParseLinks from './ParseLinks'
import LinkNode from './LinkNode'

// Mock LinkNode component
jest.mock('./LinkNode', () => {
  return function MockLinkNode({ title, type }) {
    return <a data-testid="linknode" data-title={title} data-type={type || 'default'}>{title}</a>
  }
})

describe('ParseLinks Component', () => {
  describe('plain text', () => {
    it('renders plain text without links', () => {
      render(<ParseLinks>Just plain text</ParseLinks>)
      expect(screen.getByText('Just plain text')).toBeInTheDocument()
    })

    it('handles empty string', () => {
      const { container } = render(<ParseLinks></ParseLinks>)
      expect(container).toBeEmptyDOMElement()
    })

    it('handles null children', () => {
      const { container } = render(<ParseLinks>{null}</ParseLinks>)
      expect(container).toBeEmptyDOMElement()
    })
  })

  describe('external links', () => {
    it('renders external HTTP links', () => {
      render(<ParseLinks>[http://example.com]</ParseLinks>)
      const link = screen.getByRole('link')
      expect(link).toHaveAttribute('href', 'http://example.com')
      expect(link).toHaveAttribute('rel', 'nofollow')
      expect(link).toHaveAttribute('class', 'externalLink')
      expect(link).toHaveTextContent('http://example.com')
    })

    it('renders external HTTPS links', () => {
      render(<ParseLinks>[https://example.com]</ParseLinks>)
      const link = screen.getByRole('link')
      expect(link).toHaveAttribute('href', 'https://example.com')
    })

    it('renders external links with custom display text', () => {
      render(<ParseLinks>[http://example.com|Example Site]</ParseLinks>)
      const link = screen.getByRole('link')
      expect(link).toHaveAttribute('href', 'http://example.com')
      expect(link).toHaveTextContent('Example Site')
    })

    it('handles multiple external links', () => {
      render(<ParseLinks>Check [http://foo.com] and [https://bar.com]</ParseLinks>)
      const links = screen.getAllByRole('link')
      expect(links).toHaveLength(2)
      expect(links[0]).toHaveAttribute('href', 'http://foo.com')
      expect(links[1]).toHaveAttribute('href', 'https://bar.com')
    })
  })

  describe('internal E2 links', () => {
    it('renders internal node links', () => {
      render(<ParseLinks>[Everything2]</ParseLinks>)
      const link = screen.getByTestId('linknode')
      expect(link).toHaveAttribute('data-title', 'Everything2')
    })

    it('renders internal links with pipe syntax', () => {
      render(<ParseLinks>[Everything2|E2]</ParseLinks>)
      const link = screen.getByTestId('linknode')
      expect(link).toHaveAttribute('data-title', 'Everything2')
      // Note: Display text handling would be in LinkNode component
    })

    it('handles multiple internal links', () => {
      render(<ParseLinks>[node1] and [node2]</ParseLinks>)
      const links = screen.getAllByTestId('linknode')
      expect(links).toHaveLength(2)
      expect(links[0]).toHaveAttribute('data-title', 'node1')
      expect(links[1]).toHaveAttribute('data-title', 'node2')
    })
  })

  describe('nested bracket syntax for explicit nodetype', () => {
    it('renders links with nested bracket syntax [title[nodetype]]', () => {
      render(<ParseLinks>[root[user]]</ParseLinks>)
      const link = screen.getByTestId('linknode')
      expect(link).toHaveAttribute('data-title', 'root')
      expect(link).toHaveAttribute('data-type', 'user')
    })

    it('handles multiple nested bracket links', () => {
      render(<ParseLinks>[root[user]] and [Everything2[superdoc]]</ParseLinks>)
      const links = screen.getAllByTestId('linknode')
      expect(links).toHaveLength(2)
      expect(links[0]).toHaveAttribute('data-title', 'root')
      expect(links[0]).toHaveAttribute('data-type', 'user')
      expect(links[1]).toHaveAttribute('data-title', 'Everything2')
      expect(links[1]).toHaveAttribute('data-type', 'superdoc')
    })

    it('handles nested brackets in context (like node notes)', () => {
      render(<ParseLinks>[root[user]]: test note</ParseLinks>)
      const link = screen.getByTestId('linknode')
      expect(link).toHaveAttribute('data-title', 'root')
      expect(link).toHaveAttribute('data-type', 'user')
      expect(screen.getByText(/: test note/)).toBeInTheDocument()
    })

    it('handles mixed simple and nested bracket links', () => {
      render(<ParseLinks>[simple link] and [typed[user]]</ParseLinks>)
      const links = screen.getAllByTestId('linknode')
      expect(links).toHaveLength(2)
      expect(links[0]).toHaveAttribute('data-title', 'simple link')
      expect(links[0]).toHaveAttribute('data-type', 'default')
      expect(links[1]).toHaveAttribute('data-title', 'typed')
      expect(links[1]).toHaveAttribute('data-type', 'user')
    })
  })

  describe('mixed content', () => {
    it('renders text before and after links', () => {
      render(<ParseLinks>Before [Everything2] after</ParseLinks>)
      expect(screen.getByText(/Before/)).toBeInTheDocument()
      expect(screen.getByText(/after/)).toBeInTheDocument()
      expect(screen.getByTestId('linknode')).toBeInTheDocument()
    })

    it('renders mixed external and internal links', () => {
      render(
        <ParseLinks>
          Check [http://example.com] and [Everything2]
        </ParseLinks>
      )
      const externalLink = screen.getByRole('link')
      const internalLink = screen.getByTestId('linknode')
      expect(externalLink).toHaveAttribute('href', 'http://example.com')
      expect(internalLink).toHaveAttribute('data-title', 'Everything2')
    })

    it('handles complex mixed content', () => {
      render(
        <ParseLinks>
          Visit [https://example.com|Example] or read [Everything2] for more
        </ParseLinks>
      )
      const externalLink = screen.getByRole('link')
      const internalLink = screen.getByTestId('linknode')
      expect(externalLink).toHaveTextContent('Example')
      expect(internalLink).toHaveAttribute('data-title', 'Everything2')
      expect(screen.getByText(/Visit/)).toBeInTheDocument()
      expect(screen.getByText(/for more/)).toBeInTheDocument()
    })
  })

  describe('edge cases', () => {
    it('handles brackets without links', () => {
      render(<ParseLinks>Some text [] more text</ParseLinks>)
      expect(screen.getByText(/Some text/)).toBeInTheDocument()
      expect(screen.getByText(/more text/)).toBeInTheDocument()
    })

    it('handles unclosed brackets', () => {
      render(<ParseLinks>Text with [unclosed bracket</ParseLinks>)
      expect(screen.getByText(/Text with/)).toBeInTheDocument()
    })

    it('handles nested brackets in external links', () => {
      render(<ParseLinks>[http://example.com]</ParseLinks>)
      const link = screen.getByRole('link')
      expect(link).toHaveAttribute('href', 'http://example.com')
    })
  })
})
