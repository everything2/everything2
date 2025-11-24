import React from 'react'
import { render, screen } from '@testing-library/react'
import '@testing-library/jest-dom'
import Categories from './Categories'

// Mock the child components
jest.mock('../NodeletContainer', () => {
  return function MockNodeletContainer({ title, children, collapsible }) {
    return (
      <div data-testid="nodelet-container" data-collapsible={collapsible}>
        <div data-testid="nodelet-title">{title}</div>
        <div data-testid="nodelet-content">{children}</div>
      </div>
    )
  }
})

jest.mock('../LinkNode', () => {
  return function MockLinkNode({ nodeId, title, type, display, lastNodeId }) {
    const displayText = display || title || `Node ${nodeId}`
    return (
      <a
        data-testid="link-node"
        data-node-id={nodeId}
        data-title={title}
        data-type={type}
        data-display={display}
        data-last-node-id={lastNodeId}
      >
        {displayText}
      </a>
    )
  }
})

describe('Categories', () => {
  const mockCategories = [
    {
      node_id: 101,
      title: 'Science Fiction',
      author_user: 201,
      author_username: 'scifiguy'
    },
    {
      node_id: 102,
      title: 'Fantasy',
      author_user: 202,
      author_username: 'fantasyfan'
    },
    {
      node_id: 103,
      title: 'Mystery',
      author_user: 203,
      author_username: 'detectivefan'
    }
  ]

  describe('Rendering', () => {
    test('renders nodelet container with title', () => {
      render(<Categories categories={mockCategories} currentNodeId={100} />)
      expect(screen.getByTestId('nodelet-title')).toHaveTextContent('Categories')
    })

    test('renders all categories', () => {
      render(<Categories categories={mockCategories} currentNodeId={100} />)
      expect(screen.getByText(/Science Fiction/)).toBeInTheDocument()
      expect(screen.getByText(/Fantasy/)).toBeInTheDocument()
      expect(screen.getByText(/Mystery/)).toBeInTheDocument()
    })

    test('renders category authors', () => {
      render(<Categories categories={mockCategories} currentNodeId={100} />)
      expect(screen.getByText(/scifiguy/)).toBeInTheDocument()
      expect(screen.getByText(/fantasyfan/)).toBeInTheDocument()
      expect(screen.getByText(/detectivefan/)).toBeInTheDocument()
    })

    test('renders add links for each category', () => {
      const { container } = render(<Categories categories={mockCategories} currentNodeId={100} />)
      const addLinks = container.querySelectorAll('a:not([data-testid="link-node"])')
      expect(addLinks).toHaveLength(3)
      addLinks.forEach(link => {
        expect(link).toHaveTextContent('add')
      })
    })

    test('add links have correct URL format', () => {
      const currentNodeId = 100
      const { container } = render(<Categories categories={mockCategories} currentNodeId={currentNodeId} />)
      const addLinks = container.querySelectorAll('a:not([data-testid="link-node"])')

      addLinks.forEach((link, index) => {
        const categoryId = mockCategories[index].node_id
        expect(link.getAttribute('href')).toBe(
          `/index.pl?op=category&node_id=${currentNodeId}&cid=${categoryId}&nid=${currentNodeId}`
        )
      })
    })

    test('renders Create Category footer link', () => {
      render(<Categories categories={mockCategories} currentNodeId={100} />)
      const links = screen.getAllByTestId('link-node')
      const createLink = links.find(link => link.getAttribute('data-title') === 'Create category')
      expect(createLink).toBeDefined()
      expect(createLink).toHaveAttribute('data-title', 'Create category')
      expect(createLink).toHaveAttribute('data-type', 'superdoc')
      expect(createLink).toHaveAttribute('data-display', 'Add a new Category')
      expect(createLink).toHaveTextContent('Add a new Category')
    })
  })

  describe('Empty States', () => {
    test('renders empty message when categories is undefined', () => {
      render(<Categories currentNodeId={100} />)
      expect(screen.getByText(/No categories available/i)).toBeInTheDocument()
    })

    test('renders empty message when categories is null', () => {
      render(<Categories categories={null} currentNodeId={100} />)
      expect(screen.getByText(/No categories available/i)).toBeInTheDocument()
    })

    test('renders empty message when categories is not an array', () => {
      render(<Categories categories="not an array" currentNodeId={100} />)
      expect(screen.getByText(/No categories available/i)).toBeInTheDocument()
    })

    test('renders empty message when categories is empty array', () => {
      render(<Categories categories={[]} currentNodeId={100} />)
      expect(screen.getByText(/No categories available/i)).toBeInTheDocument()
    })

    test('empty state still renders nodelet container', () => {
      render(<Categories currentNodeId={100} />)
      expect(screen.getByTestId('nodelet-container')).toBeInTheDocument()
      expect(screen.getByTestId('nodelet-title')).toHaveTextContent('Categories')
    })
  })

  describe('Data Structure', () => {
    test('renders with single category', () => {
      const singleCategory = [mockCategories[0]]
      render(<Categories categories={singleCategory} currentNodeId={100} />)
      expect(screen.getByText(/Science Fiction/)).toBeInTheDocument()
      expect(screen.getByText(/scifiguy/)).toBeInTheDocument()
    })

    test('handles category without author username gracefully', () => {
      const categoriesWithoutAuthor = [{
        node_id: 101,
        title: 'No Author',
        author_user: 201
      }]
      render(<Categories categories={categoriesWithoutAuthor} currentNodeId={100} />)
      expect(screen.getByText(/No Author/)).toBeInTheDocument()
    })

    test('renders categories in order provided', () => {
      const { container } = render(<Categories categories={mockCategories} currentNodeId={100} />)
      const listItems = container.querySelectorAll('li')
      expect(listItems[0]).toHaveTextContent('Science Fiction')
      expect(listItems[1]).toHaveTextContent('Fantasy')
      expect(listItems[2]).toHaveTextContent('Mystery')
    })
  })

  describe('LinkNode Integration', () => {
    test('passes correct props to category LinkNode', () => {
      render(<Categories categories={mockCategories} currentNodeId={100} />)
      const categoryLinks = screen.getAllByTestId('link-node')

      // First category link (plus author links)
      expect(categoryLinks[0]).toHaveAttribute('data-node-id', '101')
      expect(categoryLinks[0]).toHaveAttribute('data-last-node-id', '0')
    })

    test('passes correct props to author LinkNode', () => {
      render(<Categories categories={mockCategories} currentNodeId={100} />)
      const links = screen.getAllByTestId('link-node')

      // Second link in first list item is the author
      expect(links[1]).toHaveAttribute('data-node-id', '201')
      expect(links[1]).toHaveAttribute('data-last-node-id', '0')
    })

    test('passes correct props to Create Category LinkNode', () => {
      render(<Categories categories={mockCategories} currentNodeId={100} />)

      // Find the Create Category link by its unique attributes
      const createLink = screen.getAllByTestId('link-node').find(
        link => link.getAttribute('data-title') === 'Create category'
      )

      expect(createLink).toBeDefined()
      expect(createLink).toHaveAttribute('data-title', 'Create category')
      expect(createLink).toHaveAttribute('data-type', 'superdoc')
      expect(createLink).toHaveAttribute('data-display', 'Add a new Category')
    })
  })

  describe('HTML Structure', () => {
    test('renders list with correct id', () => {
      const { container } = render(<Categories categories={mockCategories} currentNodeId={100} />)
      const list = container.querySelector('#nodelists')
      expect(list).toBeInTheDocument()
      expect(list.tagName).toBe('UL')
    })

    test('renders correct number of list items', () => {
      const { container } = render(<Categories categories={mockCategories} currentNodeId={100} />)
      const listItems = container.querySelectorAll('li')
      expect(listItems).toHaveLength(mockCategories.length)
    })

    test('renders footer with correct class', () => {
      const { container } = render(<Categories categories={mockCategories} currentNodeId={100} />)
      const footer = container.querySelector('.nodeletfoot')
      expect(footer).toBeInTheDocument()
    })

    test('each list item has unique key (no console warnings)', () => {
      const consoleSpy = jest.spyOn(console, 'error').mockImplementation(() => {})
      render(<Categories categories={mockCategories} currentNodeId={100} />)
      expect(consoleSpy).not.toHaveBeenCalledWith(
        expect.stringContaining('unique "key" prop')
      )
      consoleSpy.mockRestore()
    })
  })

  describe('Edge Cases', () => {
    test('handles very long category title', () => {
      const longTitle = 'A'.repeat(200)
      const categoriesWithLongTitle = [{
        node_id: 101,
        title: longTitle,
        author_user: 201,
        author_username: 'testuser'
      }]
      render(<Categories categories={categoriesWithLongTitle} currentNodeId={100} />)
      expect(screen.getByText(new RegExp(longTitle))).toBeInTheDocument()
    })

    test('handles special characters in category title', () => {
      const specialCategories = [{
        node_id: 101,
        title: 'C++ & Programming <tricks>',
        author_user: 201,
        author_username: 'coder'
      }]
      render(<Categories categories={specialCategories} currentNodeId={100} />)
      expect(screen.getByText(/C\+\+ & Programming/)).toBeInTheDocument()
    })

    test('handles missing currentNodeId gracefully', () => {
      render(<Categories categories={mockCategories} />)
      const { container } = render(<Categories categories={mockCategories} />)
      const addLinks = container.querySelectorAll('a:not([data-testid="link-node"])')
      expect(addLinks[0].getAttribute('href')).toContain('node_id=undefined')
    })

    test('handles zero node IDs', () => {
      const zeroIdCategories = [{
        node_id: 0,
        title: 'Zero Category',
        author_user: 0,
        author_username: 'root'
      }]
      render(<Categories categories={zeroIdCategories} currentNodeId={0} />)
      expect(screen.getByText(/Zero Category/)).toBeInTheDocument()
    })
  })

  describe('Styling', () => {
    test('list has correct styling attributes', () => {
      const { container } = render(<Categories categories={mockCategories} currentNodeId={100} />)
      const list = container.querySelector('#nodelists')
      expect(list).toHaveStyle({ listStyle: 'disc' })
      expect(list).toHaveStyle({ paddingLeft: '24px' })
    })

    test('empty state message has correct styling', () => {
      const { container } = render(<Categories categories={[]} currentNodeId={100} />)
      const emptyMessage = container.querySelector('p')
      expect(emptyMessage).toHaveStyle({ padding: '8px' })
      expect(emptyMessage).toHaveStyle({ color: '#666' })
      expect(emptyMessage).toHaveStyle({ fontSize: '12px' })
    })
  })
})
