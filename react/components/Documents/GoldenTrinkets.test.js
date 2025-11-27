import React from 'react'
import { render, screen } from '@testing-library/react'
import GoldenTrinkets from './GoldenTrinkets'

// Mock LinkNode component
jest.mock('../LinkNode', () => {
  return function MockLinkNode({ title, type, display }) {
    return <a href={`/node/${type}/${title}`}>{display || title}</a>
  }
})

describe('GoldenTrinkets', () => {
  const mockUser = {
    is_admin: false,
    node_id: 123,
    title: 'testuser'
  }

  describe('karma display', () => {
    it('shows "not feeling very special" when karma is 0', () => {
      const data = { karma: 0, isAdmin: 0 }
      render(<GoldenTrinkets data={data} user={mockUser} />)

      expect(screen.getByText(/You are not feeling very special/)).toBeInTheDocument()
    })

    it('shows "burning sensation" when karma is negative', () => {
      const data = { karma: -5, isAdmin: 0 }
      render(<GoldenTrinkets data={data} user={mockUser} />)

      expect(screen.getByText(/You feel a burning sensation/)).toBeInTheDocument()
    })

    it('shows blessing message when karma is positive', () => {
      const data = { karma: 42, isAdmin: 0 }
      render(<GoldenTrinkets data={data} user={mockUser} />)

      expect(
        screen.getByText(/You feel blessed -- every day, the gods see you and are glad/)
      ).toBeInTheDocument()
      expect(screen.getByText(/you have collected 42 of their/)).toBeInTheDocument()
      expect(screen.getByText('Golden Trinkets')).toBeInTheDocument()
    })
  })

  describe('admin lookup feature', () => {
    it('does not show admin lookup section for non-admin users', () => {
      const data = { karma: 10, isAdmin: 0 }
      render(<GoldenTrinkets data={data} user={mockUser} />)

      expect(screen.queryByText('Admin Lookup')).not.toBeInTheDocument()
    })

    it('shows admin lookup section for admin users', () => {
      const data = { karma: 10, isAdmin: 1 }
      render(<GoldenTrinkets data={data} user={{ ...mockUser, is_admin: true }} />)

      expect(screen.getByText('Admin Lookup')).toBeInTheDocument()
      expect(screen.getByPlaceholderText('Enter username')).toBeInTheDocument()
      expect(screen.getByRole('button', { name: 'Lookup' })).toBeInTheDocument()
    })

    it('displays lookup error when provided', () => {
      const data = {
        karma: 10,
        isAdmin: 1,
        error: 'User not found'
      }
      render(<GoldenTrinkets data={data} user={{ ...mockUser, is_admin: true }} />)

      expect(screen.getByText('User not found')).toBeInTheDocument()
    })

    it('displays lookup result when provided', () => {
      const data = {
        karma: 10,
        isAdmin: 1,
        forUser: {
          username: 'anotheruser',
          karma: 25,
          node_id: 456
        }
      }
      render(<GoldenTrinkets data={data} user={{ ...mockUser, is_admin: true }} />)

      expect(screen.getByText(/anotheruser/)).toBeInTheDocument()
      expect(screen.getByText(/'s karma: 25/)).toBeInTheDocument()
    })
  })

  describe('form submission', () => {
    it('renders lookup form with GET method for page reload', () => {
      const data = { karma: 10, isAdmin: 1 }
      render(<GoldenTrinkets data={data} user={{ ...mockUser, is_admin: true }} />)

      const form = screen.getByRole('button', { name: 'Lookup' }).closest('form')
      expect(form).toHaveAttribute('method', 'GET')

      const input = screen.getByPlaceholderText('Enter username')
      expect(input).toHaveAttribute('name', 'for_user')
    })
  })

  describe('edge cases', () => {
    it('handles missing karma (defaults to 0)', () => {
      const data = { isAdmin: 0 }
      render(<GoldenTrinkets data={data} user={mockUser} />)

      expect(screen.getByText(/You are not feeling very special/)).toBeInTheDocument()
    })

    it('handles missing isAdmin flag', () => {
      const data = { karma: 10 }
      render(<GoldenTrinkets data={data} user={mockUser} />)

      expect(screen.queryByText('Admin Lookup')).not.toBeInTheDocument()
    })

    it('shows neither error nor result when lookup not performed', () => {
      const data = { karma: 10, isAdmin: 1 }
      render(<GoldenTrinkets data={data} user={{ ...mockUser, is_admin: true }} />)

      expect(screen.queryByText(/User not found/)).not.toBeInTheDocument()
      expect(screen.queryByText(/'s karma:/)).not.toBeInTheDocument()
    })
  })
})
