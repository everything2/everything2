import React from 'react'
import { render, screen } from '@testing-library/react'
import '@testing-library/jest-dom'
import SourceMapModal from './SourceMapModal'

// Mock react-modal
jest.mock('react-modal', () => {
  return function MockModal({ isOpen, children }) {
    return isOpen ? <div>{children}</div> : null
  }
})

describe('SourceMapModal', () => {
  const mockSourceMap = {
    githubRepo: 'https://github.com/everything2/everything2',
    branch: 'master',
    commitHash: 'abc123',
    components: [
      {
        type: 'react_component',
        name: 'Chatterbox',
        path: 'react/components/Nodelets/Chatterbox.js',
        description: 'React component'
      },
      {
        type: 'test',
        name: 'Chatterbox.test.js',
        path: 'react/components/Nodelets/Chatterbox.test.js',
        description: 'Component tests'
      }
    ]
  }

  it('shows message when sourceMap is null', () => {
    render(
      <SourceMapModal isOpen={true} onClose={() => {}} sourceMap={null} nodeTitle="Test" />
    )
    expect(screen.getByText(/No source components detected/i)).toBeInTheDocument()
  })

  it('renders modal with node title', () => {
    render(
      <SourceMapModal
        isOpen={true}
        onClose={() => {}}
        sourceMap={mockSourceMap}
        nodeTitle="Chatterbox"
      />
    )

    expect(screen.getByText(/Source Map: Chatterbox/i)).toBeInTheDocument()
  })

  it('renders all components', () => {
    render(
      <SourceMapModal
        isOpen={true}
        onClose={() => {}}
        sourceMap={mockSourceMap}
        nodeTitle="Chatterbox"
      />
    )

    expect(screen.getByText('Chatterbox')).toBeInTheDocument()
    expect(screen.getByText('Chatterbox.test.js')).toBeInTheDocument()
    expect(screen.getByText('React component')).toBeInTheDocument()
    expect(screen.getByText('Component tests')).toBeInTheDocument()
  })

  it('renders GitHub links with correct URLs', () => {
    const { container } = render(
      <SourceMapModal
        isOpen={true}
        onClose={() => {}}
        sourceMap={mockSourceMap}
        nodeTitle="Chatterbox"
      />
    )

    const viewLinks = container.querySelectorAll('a[href*="blob"]')
    expect(viewLinks[0]).toHaveAttribute(
      'href',
      'https://github.com/everything2/everything2/blob/abc123/react/components/Nodelets/Chatterbox.js'
    )

    const editLinks = container.querySelectorAll('a[href*="edit"]')
    expect(editLinks[0]).toHaveAttribute(
      'href',
      'https://github.com/everything2/everything2/edit/master/react/components/Nodelets/Chatterbox.js'
    )
  })

  it('renders contributing guide link', () => {
    render(
      <SourceMapModal
        isOpen={true}
        onClose={() => {}}
        sourceMap={mockSourceMap}
        nodeTitle="Chatterbox"
      />
    )

    const contributingLink = screen.getByText('Contributing Guide')
    expect(contributingLink).toHaveAttribute(
      'href',
      'https://github.com/everything2/everything2/blob/master/CONTRIBUTING.md'
    )
  })

  it('shows message when no components detected', () => {
    const emptySourceMap = {
      ...mockSourceMap,
      components: []
    }

    render(
      <SourceMapModal
        isOpen={true}
        onClose={() => {}}
        sourceMap={emptySourceMap}
        nodeTitle="Test"
      />
    )

    expect(screen.getByText(/No source components detected/i)).toBeInTheDocument()
  })

  it('renders correct type labels', () => {
    const complexSourceMap = {
      ...mockSourceMap,
      components: [
        {
          type: 'react_component',
          name: 'Component',
          path: 'react/components/Component.js',
          description: 'A React component'
        },
        {
          type: 'page_class',
          name: 'page',
          path: 'ecore/Everything/Page/page.pm',
          description: 'A Perl Page Class module'
        },
        {
          type: 'delegation',
          name: 'document.pm',
          path: 'ecore/Everything/Delegation/document.pm',
          description: 'A Delegation module'
        }
      ]
    }

    render(
      <SourceMapModal
        isOpen={true}
        onClose={() => {}}
        sourceMap={complexSourceMap}
        nodeTitle="Test"
      />
    )

    // Type labels should be present (uppercase in the badge)
    expect(screen.getByText('Perl Page Class')).toBeInTheDocument()
    expect(screen.getByText('Delegation Module')).toBeInTheDocument()
  })
})
