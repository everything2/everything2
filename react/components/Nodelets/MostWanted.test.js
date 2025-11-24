import React from 'react'
import { render, screen } from '@testing-library/react'
import '@testing-library/jest-dom'
import MostWanted from './MostWanted'

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
  return function MockLinkNode({ nodeId, title, type, display }) {
    const displayText = display || title || `Node ${nodeId}`
    return (
      <a
        data-testid="link-node"
        data-node-id={nodeId}
        data-title={title}
        data-type={type}
        data-display={display}
      >
        {displayText}
      </a>
    )
  }
})

jest.mock('../ParseLinks', () => {
  return function MockParseLinks({ text }) {
    return <span data-testid="parse-links">{text}</span>
  }
})

describe('MostWanted', () => {
  const mockBounties = [
    {
      requester_id: 101,
      requester_name: 'sheriff1',
      outlaw_nodeshell: '[bad node]',
      reward: '50 GP'
    },
    {
      requester_id: 102,
      requester_name: 'sheriff2',
      outlaw_nodeshell: '[another bad node]',
      reward: '100 GP'
    },
    {
      requester_id: 103,
      requester_name: 'sheriff3',
      outlaw_nodeshell: '[yet another bad node]',
      reward: ''
    }
  ]

  describe('Rendering', () => {
    test('renders nodelet container with title', () => {
      render(<MostWanted bounties={mockBounties} />)
      expect(screen.getByTestId('nodelet-title')).toHaveTextContent('Most Wanted')
    })

    test('renders table with correct headers', () => {
      const { container } = render(<MostWanted bounties={mockBounties} />)
      expect(screen.getByText('Requesting Sheriff')).toBeInTheDocument()
      expect(screen.getByText('Outlaw Nodeshell')).toBeInTheDocument()
      expect(screen.getByText('GP Reward (if any)')).toBeInTheDocument()
    })

    test('renders all bounties', () => {
      render(<MostWanted bounties={mockBounties} />)
      const rows = screen.getAllByTestId('link-node')
      // 3 bounties * 1 link per bounty + 1 footer link = 4 total
      expect(rows.length).toBeGreaterThanOrEqual(3)
    })

    test('renders requester names', () => {
      render(<MostWanted bounties={mockBounties} />)
      expect(screen.getByText('sheriff1')).toBeInTheDocument()
      expect(screen.getByText('sheriff2')).toBeInTheDocument()
      expect(screen.getByText('sheriff3')).toBeInTheDocument()
    })

    test('renders outlaw nodeshells via ParseLinks', () => {
      render(<MostWanted bounties={mockBounties} />)
      const parseLinks = screen.getAllByTestId('parse-links')
      expect(parseLinks[0]).toHaveTextContent('[bad node]')
      expect(parseLinks[1]).toHaveTextContent('[another bad node]')
      expect(parseLinks[2]).toHaveTextContent('[yet another bad node]')
    })

    test('renders rewards', () => {
      const { container } = render(<MostWanted bounties={mockBounties} />)
      expect(screen.getByText('50 GP')).toBeInTheDocument()
      expect(screen.getByText('100 GP')).toBeInTheDocument()
    })

    test('renders footer message', () => {
      render(<MostWanted bounties={mockBounties} />)
      expect(screen.getByText(/Fill these nodes and get rewards!/)).toBeInTheDocument()
      expect(screen.getByText(/More details at/)).toBeInTheDocument()
    })

    test('renders link to Everything\'s Most Wanted', () => {
      render(<MostWanted bounties={mockBounties} />)
      const links = screen.getAllByTestId('link-node')
      const mostWantedLink = links.find(link =>
        link.getAttribute('data-title') === "Everything's Most Wanted"
      )
      expect(mostWantedLink).toBeDefined()
    })
  })

  describe('Empty States', () => {
    test('renders empty message when bounties is undefined', () => {
      render(<MostWanted />)
      expect(screen.getByText(/No bounties available/i)).toBeInTheDocument()
    })

    test('renders empty message when bounties is null', () => {
      render(<MostWanted bounties={null} />)
      expect(screen.getByText(/No bounties available/i)).toBeInTheDocument()
    })

    test('renders empty message when bounties is not an array', () => {
      render(<MostWanted bounties="not an array" />)
      expect(screen.getByText(/No bounties available/i)).toBeInTheDocument()
    })

    test('renders empty message when bounties is empty array', () => {
      render(<MostWanted bounties={[]} />)
      expect(screen.getByText(/No bounties available/i)).toBeInTheDocument()
    })

    test('empty state still renders nodelet container', () => {
      render(<MostWanted />)
      expect(screen.getByTestId('nodelet-container')).toBeInTheDocument()
      expect(screen.getByTestId('nodelet-title')).toHaveTextContent('Most Wanted')
    })
  })

  describe('Data Structure', () => {
    test('renders with single bounty', () => {
      const singleBounty = [mockBounties[0]]
      render(<MostWanted bounties={singleBounty} />)
      expect(screen.getByText('sheriff1')).toBeInTheDocument()
      expect(screen.getByText('50 GP')).toBeInTheDocument()
    })

    test('handles bounty without reward', () => {
      render(<MostWanted bounties={mockBounties} />)
      const { container } = render(<MostWanted bounties={mockBounties} />)
      const tbody = container.querySelector('tbody')
      expect(tbody).toBeInTheDocument()
    })

    test('renders bounties in order provided', () => {
      const { container } = render(<MostWanted bounties={mockBounties} />)
      const rows = container.querySelectorAll('tbody tr')
      expect(rows).toHaveLength(3)
    })

    test('handles empty reward string', () => {
      const bountiesWithEmptyReward = [{
        requester_id: 101,
        requester_name: 'sheriff1',
        outlaw_nodeshell: '[bad node]',
        reward: ''
      }]
      render(<MostWanted bounties={bountiesWithEmptyReward} />)
      expect(screen.getByText('sheriff1')).toBeInTheDocument()
    })
  })

  describe('LinkNode Integration', () => {
    test('passes correct props to requester LinkNode', () => {
      render(<MostWanted bounties={mockBounties} />)
      const links = screen.getAllByTestId('link-node')

      // Find the sheriff1 link
      const sheriff1Link = links.find(link => link.textContent === 'sheriff1')
      expect(sheriff1Link).toBeDefined()
      expect(sheriff1Link).toHaveAttribute('data-node-id', '101')
    })

    test('renders correct number of requester links', () => {
      render(<MostWanted bounties={mockBounties} />)
      expect(screen.getByText('sheriff1')).toBeInTheDocument()
      expect(screen.getByText('sheriff2')).toBeInTheDocument()
      expect(screen.getByText('sheriff3')).toBeInTheDocument()
    })

    test('passes correct props to footer LinkNode', () => {
      render(<MostWanted bounties={mockBounties} />)
      const links = screen.getAllByTestId('link-node')
      const footerLink = links.find(link =>
        link.getAttribute('data-title') === "Everything's Most Wanted"
      )
      expect(footerLink).toBeDefined()
    })
  })

  describe('ParseLinks Integration', () => {
    test('passes outlaw nodeshell text to ParseLinks', () => {
      render(<MostWanted bounties={mockBounties} />)
      const parseLinks = screen.getAllByTestId('parse-links')
      expect(parseLinks[0]).toHaveTextContent('[bad node]')
    })

    test('renders correct number of ParseLinks', () => {
      render(<MostWanted bounties={mockBounties} />)
      const parseLinks = screen.getAllByTestId('parse-links')
      expect(parseLinks).toHaveLength(3)
    })
  })

  describe('HTML Structure', () => {
    test('renders table with mytable class', () => {
      const { container } = render(<MostWanted bounties={mockBounties} />)
      const table = container.querySelector('table.mytable')
      expect(table).toBeInTheDocument()
    })

    test('renders thead with correct headers', () => {
      const { container } = render(<MostWanted bounties={mockBounties} />)
      const thead = container.querySelector('thead')
      expect(thead).toBeInTheDocument()
      expect(thead.querySelectorAll('th')).toHaveLength(3)
    })

    test('renders tbody with correct number of rows', () => {
      const { container } = render(<MostWanted bounties={mockBounties} />)
      const tbody = container.querySelector('tbody')
      expect(tbody.querySelectorAll('tr')).toHaveLength(3)
    })

    test('each row has three cells', () => {
      const { container } = render(<MostWanted bounties={mockBounties} />)
      const rows = container.querySelectorAll('tbody tr')
      rows.forEach(row => {
        expect(row.querySelectorAll('td')).toHaveLength(3)
      })
    })

    test('footer is in paragraph with small tag', () => {
      const { container } = render(<MostWanted bounties={mockBounties} />)
      const footer = container.querySelector('p small')
      expect(footer).toBeInTheDocument()
      expect(footer).toHaveTextContent(/Fill these nodes/)
    })

    test('each row has unique key (no console warnings)', () => {
      const consoleSpy = jest.spyOn(console, 'error').mockImplementation(() => {})
      render(<MostWanted bounties={mockBounties} />)
      expect(consoleSpy).not.toHaveBeenCalledWith(
        expect.stringContaining('unique "key" prop')
      )
      consoleSpy.mockRestore()
    })
  })

  describe('Edge Cases', () => {
    test('handles very long outlaw nodeshell', () => {
      const longBounties = [{
        requester_id: 101,
        requester_name: 'sheriff1',
        outlaw_nodeshell: '[' + 'A'.repeat(200) + ']',
        reward: '50 GP'
      }]
      render(<MostWanted bounties={longBounties} />)
      const parseLinks = screen.getByTestId('parse-links')
      expect(parseLinks.textContent.length).toBeGreaterThan(100)
    })

    test('handles special characters in reward', () => {
      const specialBounties = [{
        requester_id: 101,
        requester_name: 'sheriff1',
        outlaw_nodeshell: '[bad node]',
        reward: '50 GP & tokens'
      }]
      render(<MostWanted bounties={specialBounties} />)
      expect(screen.getByText('50 GP & tokens')).toBeInTheDocument()
    })

    test('handles zero requester ID', () => {
      const zeroBounties = [{
        requester_id: 0,
        requester_name: 'root',
        outlaw_nodeshell: '[test]',
        reward: '0 GP'
      }]
      render(<MostWanted bounties={zeroBounties} />)
      expect(screen.getByText('root')).toBeInTheDocument()
    })

    test('handles missing requester_name', () => {
      const missingNameBounties = [{
        requester_id: 101,
        outlaw_nodeshell: '[bad node]',
        reward: '50 GP'
      }]
      render(<MostWanted bounties={missingNameBounties} />)
      // Should still render without error
      expect(screen.getByTestId('nodelet-container')).toBeInTheDocument()
    })
  })

  describe('Styling', () => {
    test('table has correct styling', () => {
      const { container } = render(<MostWanted bounties={mockBounties} />)
      const table = container.querySelector('table')
      expect(table).toHaveStyle({ width: '100%' })
      expect(table).toHaveStyle({ fontSize: '12px' })
      expect(table).toHaveStyle({ borderCollapse: 'collapse' })
    })

    test('footer has correct styling', () => {
      const { container } = render(<MostWanted bounties={mockBounties} />)
      const footer = container.querySelector('p')
      expect(footer).toHaveStyle({ fontSize: '11px' })
      expect(footer).toHaveStyle({ marginTop: '8px' })
    })

    test('empty state message has correct styling', () => {
      const { container } = render(<MostWanted bounties={[]} />)
      const emptyMessage = container.querySelector('p')
      expect(emptyMessage).toHaveStyle({ padding: '8px' })
      expect(emptyMessage).toHaveStyle({ color: '#666' })
      expect(emptyMessage).toHaveStyle({ fontSize: '12px' })
    })

    test('table headers have left alignment', () => {
      const { container } = render(<MostWanted bounties={mockBounties} />)
      const headers = container.querySelectorAll('th')
      headers.forEach(header => {
        expect(header).toHaveStyle({ textAlign: 'left' })
      })
    })
  })
})
