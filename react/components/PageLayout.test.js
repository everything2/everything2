import React from 'react'
import { act, render, screen } from '@testing-library/react'
import PageLayout from './PageLayout'

// Mock DocumentComponent
jest.mock('./DocumentComponent', () => {
  return function MockDocumentComponent({ data, user, e2 }) {
    return (
      <div data-testid="document-component">
        Document: {data?.type || 'unknown'}
        {user && <span> - User: {user.title}</span>}
        {user && user.votesleft !== undefined && (
          <span data-testid="doc-votesleft">{user.votesleft}</span>
        )}
        {user && user.coolsleft !== undefined && (
          <span data-testid="doc-coolsleft">{user.coolsleft}</span>
        )}
      </div>
    )
  }
})

// Mock MasonContent
jest.mock('./MasonContent', () => {
  return function MockMasonContent({ html }) {
    return <div data-testid="mason-content" dangerouslySetInnerHTML={{ __html: html }} />
  }
})

// Mock E2ReactRoot (sidebar) - not the focus of these tests
jest.mock('./E2ReactRoot', () => {
  return function MockE2ReactRoot() {
    return <div data-testid="sidebar">Sidebar</div>
  }
})

// Mock Layout components
jest.mock('./Layout/Header', () => {
  return function MockHeader() {
    return <div data-testid="header">Header</div>
  }
})

jest.mock('./Layout/PageHeader', () => {
  return function MockPageHeader({ node, children }) {
    return (
      <div data-testid="pageheader">
        <h1 data-testid="pageheader-title">{node?.title}</h1>
        {children}
      </div>
    )
  }
})

jest.mock('./Layout/GoogleAds', () => {
  const MockGoogleAds = () => null
  MockGoogleAds.FooterAd = () => null
  return MockGoogleAds
})

jest.mock('./PageActions', () => {
  return function MockPageActions() {
    return null
  }
})

describe('PageLayout', () => {
  describe('with contentData', () => {
    it('renders DocumentComponent when contentData is provided', () => {
      const e2 = {
        contentData: { type: 'e2node', title: 'Test Node' },
        user: { node_id: 123, title: 'testuser' }
      }

      render(<PageLayout e2={e2} />)

      expect(screen.getByTestId('document-component')).toBeInTheDocument()
      expect(screen.getByText(/Document: e2node/)).toBeInTheDocument()
    })

    it('passes user to DocumentComponent', () => {
      const e2 = {
        contentData: { type: 'writeup' },
        user: { node_id: 123, title: 'testuser' }
      }

      render(<PageLayout e2={e2} />)

      expect(screen.getByText(/User: testuser/)).toBeInTheDocument()
    })

    it('prefers contentData over contentHtml', () => {
      const e2 = {
        contentData: { type: 'e2node' },
        contentHtml: '<p>HTML content</p>',
        user: null
      }

      render(<PageLayout e2={e2} />)

      expect(screen.getByTestId('document-component')).toBeInTheDocument()
      expect(screen.queryByTestId('mason-content')).not.toBeInTheDocument()
    })
  })

  describe('with contentHtml', () => {
    it('renders MasonContent when contentHtml is provided', () => {
      const e2 = {
        contentHtml: '<p>Legacy HTML content</p>'
      }

      render(<PageLayout e2={e2} />)

      expect(screen.getByTestId('mason-content')).toBeInTheDocument()
      expect(screen.getByText('Legacy HTML content')).toBeInTheDocument()
    })

    it('renders complex HTML content', () => {
      const e2 = {
        contentHtml: '<div><h1>Title</h1><p>Paragraph</p></div>'
      }

      render(<PageLayout e2={e2} />)

      expect(screen.getByText('Title')).toBeInTheDocument()
      expect(screen.getByText('Paragraph')).toBeInTheDocument()
    })
  })

  describe('fallback behavior', () => {
    it('shows fallback message when no content is provided', () => {
      const e2 = {}

      render(<PageLayout e2={e2} />)

      expect(screen.getByText('No content available')).toBeInTheDocument()
    })

    it('shows fallback when contentData is null', () => {
      const e2 = {
        contentData: null,
        contentHtml: null
      }

      render(<PageLayout e2={e2} />)

      expect(screen.getByText('No content available')).toBeInTheDocument()
    })

    it('shows fallback when contentData is undefined and contentHtml is empty', () => {
      const e2 = {
        contentHtml: ''
      }

      render(<PageLayout e2={e2} />)

      // Empty string is falsy, so should show fallback
      expect(screen.getByText('No content available')).toBeInTheDocument()
    })
  })

  describe('e2:userUpdate event', () => {
    it('refreshes user-derived props when e2:userUpdate fires', () => {
      const e2 = {
        contentData: { type: 'writeup' },
        user: { node_id: 123, title: 'testuser', votesleft: 10, coolsleft: 3 }
      }

      render(<PageLayout e2={e2} />)
      expect(screen.getByTestId('doc-votesleft')).toHaveTextContent('10')
      expect(screen.getByTestId('doc-coolsleft')).toHaveTextContent('3')

      act(() => {
        window.dispatchEvent(new CustomEvent('e2:userUpdate', {
          detail: { votesleft: 9 }
        }))
      })
      expect(screen.getByTestId('doc-votesleft')).toHaveTextContent('9')
      expect(screen.getByTestId('doc-coolsleft')).toHaveTextContent('3')

      act(() => {
        window.dispatchEvent(new CustomEvent('e2:userUpdate', {
          detail: { coolsleft: 2 }
        }))
      })
      expect(screen.getByTestId('doc-coolsleft')).toHaveTextContent('2')
    })
  })

  describe('e2:nodeTitleUpdate event (#4224)', () => {
    it('updates the page header H1 when the node title changes in place', () => {
      const e2 = {
        contentData: { type: 'writeup' },
        user: null,
        node: { node_id: 100, title: 'Hippopotamus (thing)' }
      }

      render(<PageLayout e2={e2} />)
      expect(screen.getByTestId('pageheader-title')).toHaveTextContent('Hippopotamus (thing)')

      act(() => {
        window.dispatchEvent(new CustomEvent('e2:nodeTitleUpdate', {
          detail: { title: 'Hippopotamus (idea)' }
        }))
      })
      expect(screen.getByTestId('pageheader-title')).toHaveTextContent('Hippopotamus (idea)')
    })

    it('ignores an event with no title', () => {
      const e2 = {
        contentData: { type: 'writeup' },
        user: null,
        node: { node_id: 100, title: 'Hippopotamus (thing)' }
      }

      render(<PageLayout e2={e2} />)
      act(() => {
        window.dispatchEvent(new CustomEvent('e2:nodeTitleUpdate', { detail: {} }))
      })
      expect(screen.getByTestId('pageheader-title')).toHaveTextContent('Hippopotamus (thing)')
    })
  })

  describe('edge cases', () => {
    it('handles e2 with only user data', () => {
      const e2 = {
        user: { node_id: 123, title: 'testuser' }
      }

      render(<PageLayout e2={e2} />)

      expect(screen.getByText('No content available')).toBeInTheDocument()
    })

    it('handles contentData with empty object', () => {
      const e2 = {
        contentData: {}
      }

      render(<PageLayout e2={e2} />)

      // Empty object is truthy, so should render DocumentComponent
      expect(screen.getByTestId('document-component')).toBeInTheDocument()
    })
  })
})
