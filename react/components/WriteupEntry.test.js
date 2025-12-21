import React from 'react'
import { render, screen } from '@testing-library/react'
import WriteupEntry from './WriteupEntry'

// Mock the EditorHideWriteup component
jest.mock('./EditorHideWriteup', () => {
  return function MockEditorHideWriteup({ entry }) {
    return <span data-testid="editor-hide-writeup">EditorHide: {entry.node_id}</span>
  }
})

describe('WriteupEntry', () => {
  const mockEntry = {
    node_id: 123,
    title: 'Test Writeup',
    parent: { node_id: 456, title: 'Test E2Node' },
    author: { node_id: 789, title: 'testauthor' },
    writeuptype: 'thing',
    hasvoted: false
  }

  describe('full mode (default)', () => {
    it('renders parent title as link', () => {
      render(<WriteupEntry entry={mockEntry} mode="full" />)
      expect(screen.getByText('Test E2Node')).toBeInTheDocument()
    })

    it('renders writeup type', () => {
      render(<WriteupEntry entry={mockEntry} mode="full" />)
      expect(screen.getByText('thing')).toBeInTheDocument()
    })

    it('renders author with "by" prefix', () => {
      render(<WriteupEntry entry={mockEntry} mode="full" />)
      expect(screen.getByText('testauthor')).toBeInTheDocument()
      expect(screen.getByText(/by/)).toBeInTheDocument()
    })
  })

  describe('standard mode', () => {
    it('renders node title directly (not parent)', () => {
      render(<WriteupEntry entry={mockEntry} mode="standard" />)
      expect(screen.getByText('Test Writeup')).toBeInTheDocument()
    })

    it('renders author', () => {
      render(<WriteupEntry entry={mockEntry} mode="standard" />)
      expect(screen.getByText('testauthor')).toBeInTheDocument()
    })

    it('does not render writeup type', () => {
      render(<WriteupEntry entry={mockEntry} mode="standard" />)
      expect(screen.queryByText('thing')).not.toBeInTheDocument()
    })
  })

  describe('simple mode', () => {
    it('renders only the title', () => {
      render(<WriteupEntry entry={mockEntry} mode="simple" />)
      expect(screen.getByText('Test Writeup')).toBeInTheDocument()
    })

    it('does not render author', () => {
      render(<WriteupEntry entry={mockEntry} mode="simple" />)
      expect(screen.queryByText('testauthor')).not.toBeInTheDocument()
    })

    it('does not render writeup type', () => {
      render(<WriteupEntry entry={mockEntry} mode="simple" />)
      expect(screen.queryByText('thing')).not.toBeInTheDocument()
    })
  })

  describe('override props', () => {
    it('respects showParent override', () => {
      // In simple mode, parent is not shown by default
      // But we can override it to show parent
      render(<WriteupEntry entry={mockEntry} mode="simple" showParent={true} />)
      expect(screen.getByText('Test E2Node')).toBeInTheDocument()
    })

    it('respects showAuthor override', () => {
      // In simple mode, author is not shown
      // But we can override it
      render(<WriteupEntry entry={mockEntry} mode="simple" showAuthor={true} />)
      expect(screen.getByText('testauthor')).toBeInTheDocument()
    })

    it('respects showType override', () => {
      // In standard mode, type is not shown
      // But we can override it
      render(<WriteupEntry entry={mockEntry} mode="standard" showType={true} />)
      expect(screen.getByText('thing')).toBeInTheDocument()
    })

    it('respects showMetadata override', () => {
      render(<WriteupEntry entry={mockEntry} mode="simple" showMetadata={true} metadata="[3 days]" />)
      expect(screen.getByText('[3 days]')).toBeInTheDocument()
    })
  })

  describe('metadata prop', () => {
    it('renders metadata when provided', () => {
      render(<WriteupEntry entry={mockEntry} metadata="[new]" />)
      expect(screen.getByText('[new]')).toBeInTheDocument()
    })

    it('does not render metadata section when not provided', () => {
      const { container } = render(<WriteupEntry entry={mockEntry} />)
      expect(container.querySelector('.metadata')).toBeNull()
    })
  })

  describe('custom content', () => {
    it('renders custom content when provided', () => {
      render(<WriteupEntry entry={mockEntry} customContent={<span>Custom!</span>} />)
      expect(screen.getByText('Custom!')).toBeInTheDocument()
    })
  })

  describe('editor features', () => {
    it('renders EditorHideWriteup when editor prop is true', () => {
      const editorHideWriteupChange = jest.fn()
      render(
        <WriteupEntry
          entry={mockEntry}
          editor={true}
          editorHideWriteupChange={editorHideWriteupChange}
        />
      )
      expect(screen.getByTestId('editor-hide-writeup')).toBeInTheDocument()
    })

    it('does not render EditorHideWriteup when editor is false', () => {
      render(<WriteupEntry entry={mockEntry} editor={false} />)
      expect(screen.queryByTestId('editor-hide-writeup')).not.toBeInTheDocument()
    })

    it('does not render EditorHideWriteup without callback', () => {
      render(<WriteupEntry entry={mockEntry} editor={true} />)
      expect(screen.queryByTestId('editor-hide-writeup')).not.toBeInTheDocument()
    })
  })

  describe('CSS classes', () => {
    it('applies default className', () => {
      const { container } = render(<WriteupEntry entry={mockEntry} />)
      expect(container.querySelector('li')).toHaveClass('contentinfo')
    })

    it('applies custom className', () => {
      const { container } = render(<WriteupEntry entry={mockEntry} className="custom-class" />)
      expect(container.querySelector('li')).toHaveClass('custom-class')
    })

    it('adds hasvoted class when entry has been voted on', () => {
      const votedEntry = { ...mockEntry, hasvoted: true }
      const { container } = render(<WriteupEntry entry={votedEntry} />)
      expect(container.querySelector('li')).toHaveClass('hasvoted')
    })
  })

  describe('edge cases', () => {
    it('handles missing title', () => {
      const entryNoTitle = { ...mockEntry, title: null }
      render(<WriteupEntry entry={entryNoTitle} mode="simple" />)
      expect(screen.getByText('(untitled)')).toBeInTheDocument()
    })

    it('handles missing author', () => {
      const entryNoAuthor = { ...mockEntry, author: null }
      render(<WriteupEntry entry={entryNoAuthor} mode="full" />)
      // Should render without crashing
      expect(screen.getByText('Test E2Node')).toBeInTheDocument()
      expect(screen.queryByText(/by/)).not.toBeInTheDocument()
    })

    it('handles missing parent', () => {
      const entryNoParent = { ...mockEntry, parent: null }
      render(<WriteupEntry entry={entryNoParent} mode="full" />)
      // Should render title directly when no parent
      expect(screen.getByText('Test Writeup')).toBeInTheDocument()
    })

    it('handles missing writeuptype', () => {
      const entryNoType = { ...mockEntry, writeuptype: null }
      render(<WriteupEntry entry={entryNoType} mode="full" />)
      // Should render without the type section
      expect(screen.getByText('Test E2Node')).toBeInTheDocument()
    })
  })
})
