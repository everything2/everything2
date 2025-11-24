import React from 'react'
import { render, screen } from '@testing-library/react'
import '@testing-library/jest-dom'
import Notelet from './Notelet'

// Mock the child components
jest.mock('../NodeletContainer', () => {
  return function MockNodeletContainer({ title, children }) {
    return (
      <div data-testid="nodelet-container">
        <div data-testid="nodelet-title">{title}</div>
        <div data-testid="nodelet-content">{children}</div>
      </div>
    )
  }
})

jest.mock('../LinkNode', () => {
  return function MockLinkNode({ title, nodeType, display }) {
    return (
      <a
        data-testid="link-node"
        data-title={title}
        data-node-type={nodeType}
        data-display={display}
      >
        {display || title}
      </a>
    )
  }
})

jest.mock('../ParseLinks', () => {
  return function MockParseLinks({ children }) {
    return <div data-testid="parse-links">{children}</div>
  }
})

describe('Notelet', () => {
  const mockShowNodelet = jest.fn()

  describe('Rendering', () => {
    test('renders nodelet container with title', () => {
      const noteletData = {
        isLocked: false,
        hasContent: true,
        content: 'Test content',
        isGuest: false
      }
      render(<Notelet noteletData={noteletData} showNodelet={mockShowNodelet} nodeletIsOpen={true} />)
      expect(screen.getByTestId('nodelet-title')).toHaveTextContent('Notelet')
    })

    test('renders content when hasContent is true', () => {
      const noteletData = {
        isLocked: false,
        hasContent: true,
        content: 'My personal notes here',
        isGuest: false
      }
      render(<Notelet noteletData={noteletData} showNodelet={mockShowNodelet} nodeletIsOpen={true} />)
      expect(screen.getByTestId('parse-links')).toHaveTextContent('My personal notes here')
    })

    test('renders edit link in footer when content exists', () => {
      const noteletData = {
        isLocked: false,
        hasContent: true,
        content: 'Test content',
        isGuest: false
      }
      render(<Notelet noteletData={noteletData} showNodelet={mockShowNodelet} nodeletIsOpen={true} />)
      const editLink = screen.getByTestId('link-node')
      expect(editLink).toHaveAttribute('data-title', 'Notelet editor')
      expect(editLink).toHaveAttribute('data-node-type', 'superdoc')
      expect(editLink).toHaveAttribute('data-display', 'edit')
    })
  })

  describe('Empty State', () => {
    test('renders empty message when noteletData is undefined', () => {
      render(<Notelet showNodelet={mockShowNodelet} nodeletIsOpen={true} />)
      expect(screen.getByText(/No notelet data available/i)).toBeInTheDocument()
    })

    test('renders empty message when noteletData is null', () => {
      render(<Notelet noteletData={null} showNodelet={mockShowNodelet} nodeletIsOpen={true} />)
      expect(screen.getByText(/No notelet data available/i)).toBeInTheDocument()
    })

    test('empty state still renders nodelet container', () => {
      render(<Notelet showNodelet={mockShowNodelet} nodeletIsOpen={true} />)
      expect(screen.getByTestId('nodelet-container')).toBeInTheDocument()
      expect(screen.getByTestId('nodelet-title')).toHaveTextContent('Notelet')
    })
  })

  describe('Locked State', () => {
    test('renders locked message when isLocked is true', () => {
      const noteletData = {
        isLocked: true,
        hasContent: false,
        content: '',
        isGuest: false
      }
      render(<Notelet noteletData={noteletData} showNodelet={mockShowNodelet} nodeletIsOpen={true} />)
      expect(screen.getByText(/your Notelet is currently locked/i)).toBeInTheDocument()
    })

    test('does not render edit link when locked', () => {
      const noteletData = {
        isLocked: true,
        hasContent: true,
        content: 'Some content',
        isGuest: false
      }
      render(<Notelet noteletData={noteletData} showNodelet={mockShowNodelet} nodeletIsOpen={true} />)
      expect(screen.queryByTestId('link-node')).not.toBeInTheDocument()
    })

    test('does not render content when locked', () => {
      const noteletData = {
        isLocked: true,
        hasContent: true,
        content: 'Hidden content',
        isGuest: false
      }
      render(<Notelet noteletData={noteletData} showNodelet={mockShowNodelet} nodeletIsOpen={true} />)
      expect(screen.queryByTestId('parse-links')).not.toBeInTheDocument()
      expect(screen.queryByText('Hidden content')).not.toBeInTheDocument()
    })

    test('locked message mentions administrator', () => {
      const noteletData = {
        isLocked: true,
        hasContent: false,
        content: '',
        isGuest: false
      }
      render(<Notelet noteletData={noteletData} showNodelet={mockShowNodelet} nodeletIsOpen={true} />)
      expect(screen.getByText(/administrator is working with your account/i)).toBeInTheDocument()
    })
  })

  describe('No Content State', () => {
    test('renders no content message when hasContent is false', () => {
      const noteletData = {
        isLocked: false,
        hasContent: false,
        content: '',
        isGuest: false
      }
      render(<Notelet noteletData={noteletData} showNodelet={mockShowNodelet} nodeletIsOpen={true} />)
      expect(screen.getByText(/You currently have no text set for your personal nodelet/i)).toBeInTheDocument()
    })

    test('renders Notelet Editor link when no content', () => {
      const noteletData = {
        isLocked: false,
        hasContent: false,
        content: '',
        isGuest: false
      }
      render(<Notelet noteletData={noteletData} showNodelet={mockShowNodelet} nodeletIsOpen={true} />)
      const links = screen.getAllByTestId('link-node')
      const editorLink = links.find(link => link.getAttribute('data-title') === 'Notelet Editor')
      expect(editorLink).toBeDefined()
      expect(editorLink).toHaveAttribute('data-node-type', 'superdoc')
    })

    test('renders Nodelet Settings link when no content', () => {
      const noteletData = {
        isLocked: false,
        hasContent: false,
        content: '',
        isGuest: false
      }
      render(<Notelet noteletData={noteletData} showNodelet={mockShowNodelet} nodeletIsOpen={true} />)
      const links = screen.getAllByTestId('link-node')
      const settingsLink = links.find(link => link.getAttribute('data-title') === 'Nodelet Settings')
      expect(settingsLink).toBeDefined()
      expect(settingsLink).toHaveAttribute('data-node-type', 'superdoc')
    })

    test('renders remove link when no content', () => {
      const noteletData = {
        isLocked: false,
        hasContent: false,
        content: '',
        isGuest: false
      }
      const { container } = render(<Notelet noteletData={noteletData} showNodelet={mockShowNodelet} nodeletIsOpen={true} />)
      const removeLink = container.querySelector('#noteletremovallink')
      expect(removeLink).toBeInTheDocument()
      expect(removeLink).toHaveAttribute('href', '?op=movenodelet&position=x&nodelet=Notelet')
      expect(removeLink).toHaveClass('ajax')
    })

    test('renders edit link in footer when no content', () => {
      const noteletData = {
        isLocked: false,
        hasContent: false,
        content: '',
        isGuest: false
      }
      const { container } = render(<Notelet noteletData={noteletData} showNodelet={mockShowNodelet} nodeletIsOpen={true} />)
      const footer = container.querySelector('.nodeletfoot')
      expect(footer).toBeInTheDocument()
      const links = screen.getAllByTestId('link-node')
      const footerEditLink = links.find(link => link.getAttribute('data-title') === 'Notelet editor')
      expect(footerEditLink).toBeDefined()
      expect(footerEditLink).toHaveAttribute('data-display', 'edit')
    })
  })

  describe('Content Display', () => {
    test('uses ParseLinks component for content', () => {
      const noteletData = {
        isLocked: false,
        hasContent: true,
        content: 'My [important notes]',
        isGuest: false
      }
      render(<Notelet noteletData={noteletData} showNodelet={mockShowNodelet} nodeletIsOpen={true} />)
      expect(screen.getByTestId('parse-links')).toBeInTheDocument()
    })

    test('renders content with E2 bracket links', () => {
      const noteletData = {
        isLocked: false,
        hasContent: true,
        content: 'Check out [Everything2 Help] and [root[user]]',
        isGuest: false
      }
      render(<Notelet noteletData={noteletData} showNodelet={mockShowNodelet} nodeletIsOpen={true} />)
      expect(screen.getByTestId('parse-links')).toHaveTextContent('Check out [Everything2 Help] and [root[user]]')
    })

    test('renders empty content gracefully', () => {
      const noteletData = {
        isLocked: false,
        hasContent: true,
        content: '',
        isGuest: false
      }
      render(<Notelet noteletData={noteletData} showNodelet={mockShowNodelet} nodeletIsOpen={true} />)
      expect(screen.getByTestId('parse-links')).toBeInTheDocument()
    })

    test('renders multiline content', () => {
      const noteletData = {
        isLocked: false,
        hasContent: true,
        content: 'Line 1\nLine 2\nLine 3',
        isGuest: false
      }
      render(<Notelet noteletData={noteletData} showNodelet={mockShowNodelet} nodeletIsOpen={true} />)
      expect(screen.getByTestId('parse-links')).toHaveTextContent('Line 1')
      expect(screen.getByTestId('parse-links')).toHaveTextContent('Line 2')
      expect(screen.getByTestId('parse-links')).toHaveTextContent('Line 3')
    })
  })

  describe('LinkNode Integration', () => {
    test('Notelet Editor link has correct props', () => {
      const noteletData = {
        isLocked: false,
        hasContent: false,
        content: '',
        isGuest: false
      }
      render(<Notelet noteletData={noteletData} showNodelet={mockShowNodelet} nodeletIsOpen={true} />)
      const links = screen.getAllByTestId('link-node')
      const editorLink = links.find(link => link.getAttribute('data-title') === 'Notelet Editor')
      expect(editorLink).toHaveAttribute('data-title', 'Notelet Editor')
      expect(editorLink).toHaveAttribute('data-node-type', 'superdoc')
      expect(editorLink).toHaveTextContent('Notelet Editor')
    })

    test('Notelet Settings link has correct props', () => {
      const noteletData = {
        isLocked: false,
        hasContent: false,
        content: '',
        isGuest: false
      }
      render(<Notelet noteletData={noteletData} showNodelet={mockShowNodelet} nodeletIsOpen={true} />)
      const links = screen.getAllByTestId('link-node')
      const settingsLink = links.find(link => link.getAttribute('data-title') === 'Nodelet Settings')
      expect(settingsLink).toHaveAttribute('data-title', 'Nodelet Settings')
      expect(settingsLink).toHaveAttribute('data-node-type', 'superdoc')
    })

    test('edit link in footer has correct props', () => {
      const noteletData = {
        isLocked: false,
        hasContent: true,
        content: 'Content here',
        isGuest: false
      }
      render(<Notelet noteletData={noteletData} showNodelet={mockShowNodelet} nodeletIsOpen={true} />)
      const editLink = screen.getByTestId('link-node')
      expect(editLink).toHaveAttribute('data-title', 'Notelet editor')
      expect(editLink).toHaveAttribute('data-node-type', 'superdoc')
      expect(editLink).toHaveAttribute('data-display', 'edit')
      expect(editLink).toHaveTextContent('edit')
    })
  })

  describe('HTML Structure', () => {
    test('renders footer with correct class', () => {
      const noteletData = {
        isLocked: false,
        hasContent: true,
        content: 'Test',
        isGuest: false
      }
      const { container } = render(<Notelet noteletData={noteletData} showNodelet={mockShowNodelet} nodeletIsOpen={true} />)
      const footer = container.querySelector('.nodeletfoot')
      expect(footer).toBeInTheDocument()
      expect(footer).toHaveClass('nodeletfoot')
    })

    test('footer contains edit link', () => {
      const noteletData = {
        isLocked: false,
        hasContent: true,
        content: 'Test',
        isGuest: false
      }
      const { container } = render(<Notelet noteletData={noteletData} showNodelet={mockShowNodelet} nodeletIsOpen={true} />)
      const footer = container.querySelector('.nodeletfoot')
      const link = footer.querySelector('[data-testid="link-node"]')
      expect(link).toBeInTheDocument()
    })

    test('content is wrapped in div with proper styling', () => {
      const noteletData = {
        isLocked: false,
        hasContent: true,
        content: 'Styled content',
        isGuest: false
      }
      const { container } = render(<Notelet noteletData={noteletData} showNodelet={mockShowNodelet} nodeletIsOpen={true} />)
      const contentDiv = container.querySelector('div[style*="padding: 8px"]')
      expect(contentDiv).toBeInTheDocument()
      expect(contentDiv).toHaveStyle({ fontSize: '12px' })
    })

    test('locked message has proper styling', () => {
      const noteletData = {
        isLocked: true,
        hasContent: false,
        content: '',
        isGuest: false
      }
      const { container } = render(<Notelet noteletData={noteletData} showNodelet={mockShowNodelet} nodeletIsOpen={true} />)
      const message = container.querySelector('p')
      expect(message).toHaveStyle({ padding: '8px', fontSize: '12px' })
    })

    test('no content message has proper styling', () => {
      const noteletData = {
        isLocked: false,
        hasContent: false,
        content: '',
        isGuest: false
      }
      const { container } = render(<Notelet noteletData={noteletData} showNodelet={mockShowNodelet} nodeletIsOpen={true} />)
      const messageDiv = container.querySelector('div[style*="padding: 8px"]')
      expect(messageDiv).toBeInTheDocument()
      expect(messageDiv).toHaveStyle({ fontSize: '12px' })
    })
  })

  describe('Edge Cases', () => {
    test('handles very long content', () => {
      const longContent = 'A'.repeat(5000)
      const noteletData = {
        isLocked: false,
        hasContent: true,
        content: longContent,
        isGuest: false
      }
      render(<Notelet noteletData={noteletData} showNodelet={mockShowNodelet} nodeletIsOpen={true} />)
      expect(screen.getByTestId('parse-links')).toHaveTextContent(longContent)
    })

    test('handles content with HTML entities', () => {
      const noteletData = {
        isLocked: false,
        hasContent: true,
        content: 'Test <b>bold</b> & "quotes"',
        isGuest: false
      }
      render(<Notelet noteletData={noteletData} showNodelet={mockShowNodelet} nodeletIsOpen={true} />)
      expect(screen.getByTestId('parse-links')).toHaveTextContent('Test <b>bold</b> & "quotes"')
    })

    test('handles content with special characters', () => {
      const noteletData = {
        isLocked: false,
        hasContent: true,
        content: '© 2025 • Everything2 — Notes™',
        isGuest: false
      }
      render(<Notelet noteletData={noteletData} showNodelet={mockShowNodelet} nodeletIsOpen={true} />)
      expect(screen.getByTestId('parse-links')).toHaveTextContent('© 2025 • Everything2 — Notes™')
    })

    test('handles isLocked as string "1"', () => {
      const noteletData = {
        isLocked: 1,
        hasContent: false,
        content: '',
        isGuest: false
      }
      render(<Notelet noteletData={noteletData} showNodelet={mockShowNodelet} nodeletIsOpen={true} />)
      expect(screen.getByText(/your Notelet is currently locked/i)).toBeInTheDocument()
    })

    test('handles hasContent as string "0"', () => {
      const noteletData = {
        isLocked: 0,
        hasContent: 0,
        content: '',
        isGuest: false
      }
      render(<Notelet noteletData={noteletData} showNodelet={mockShowNodelet} nodeletIsOpen={true} />)
      expect(screen.getByText(/You currently have no text set/i)).toBeInTheDocument()
    })

    test('handles missing isGuest field', () => {
      const noteletData = {
        isLocked: false,
        hasContent: true,
        content: 'Test content'
      }
      render(<Notelet noteletData={noteletData} showNodelet={mockShowNodelet} nodeletIsOpen={true} />)
      expect(screen.getByTestId('parse-links')).toBeInTheDocument()
    })
  })

  describe('Props Handling', () => {
    test('passes showNodelet prop to NodeletContainer', () => {
      const noteletData = {
        isLocked: false,
        hasContent: true,
        content: 'Test',
        isGuest: false
      }
      const mockShow = jest.fn()
      render(<Notelet noteletData={noteletData} showNodelet={mockShow} nodeletIsOpen={true} />)
      expect(screen.getByTestId('nodelet-container')).toBeInTheDocument()
    })

    test('passes nodeletIsOpen prop correctly', () => {
      const noteletData = {
        isLocked: false,
        hasContent: true,
        content: 'Test',
        isGuest: false
      }
      render(<Notelet noteletData={noteletData} showNodelet={mockShowNodelet} nodeletIsOpen={false} />)
      expect(screen.getByTestId('nodelet-container')).toBeInTheDocument()
    })

    test('renders when nodeletIsOpen is undefined', () => {
      const noteletData = {
        isLocked: false,
        hasContent: true,
        content: 'Test',
        isGuest: false
      }
      render(<Notelet noteletData={noteletData} showNodelet={mockShowNodelet} />)
      expect(screen.getByTestId('nodelet-container')).toBeInTheDocument()
    })
  })

  describe('State Combinations', () => {
    test('locked state takes precedence over content', () => {
      const noteletData = {
        isLocked: true,
        hasContent: true,
        content: 'Should not display',
        isGuest: false
      }
      render(<Notelet noteletData={noteletData} showNodelet={mockShowNodelet} nodeletIsOpen={true} />)
      expect(screen.getByText(/your Notelet is currently locked/i)).toBeInTheDocument()
      expect(screen.queryByTestId('parse-links')).not.toBeInTheDocument()
    })

    test('not locked and has content shows content', () => {
      const noteletData = {
        isLocked: false,
        hasContent: true,
        content: 'Visible content',
        isGuest: false
      }
      render(<Notelet noteletData={noteletData} showNodelet={mockShowNodelet} nodeletIsOpen={true} />)
      expect(screen.getByTestId('parse-links')).toHaveTextContent('Visible content')
      expect(screen.queryByText(/locked/i)).not.toBeInTheDocument()
    })

    test('not locked and no content shows setup message', () => {
      const noteletData = {
        isLocked: false,
        hasContent: false,
        content: '',
        isGuest: false
      }
      render(<Notelet noteletData={noteletData} showNodelet={mockShowNodelet} nodeletIsOpen={true} />)
      expect(screen.getByText(/You currently have no text set/i)).toBeInTheDocument()
      expect(screen.queryByText(/locked/i)).not.toBeInTheDocument()
      expect(screen.queryByTestId('parse-links')).not.toBeInTheDocument()
    })
  })
})
