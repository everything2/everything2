import React from 'react'
import { render, screen, waitFor } from '@testing-library/react'
import DocumentComponent from './DocumentComponent'

// Mock the eager-loaded components
jest.mock('./Documents/Writeup', () => {
  return function MockWriteup({ data, user, e2 }) {
    return (
      <div data-testid="writeup-component">
        Writeup: {data.title || 'Untitled'}
      </div>
    )
  }
})

jest.mock('./Documents/E2Node', () => {
  return function MockE2Node({ data, user, e2 }) {
    return (
      <div data-testid="e2node-component">
        E2Node: {data.title || 'Untitled'}
      </div>
    )
  }
})

// Mock lazy-loaded components - we'll test a few key ones
jest.mock('./Documents/Settings', () => {
  return function MockSettings({ data, user, e2 }) {
    return <div data-testid="settings-component">Settings</div>
  }
})

jest.mock('./Documents/Login', () => {
  return function MockLogin({ data, user, e2 }) {
    return <div data-testid="login-component">Login</div>
  }
})

jest.mock('./Documents/WheelOfSurprise', () => {
  return function MockWheelOfSurprise({ data, user, e2 }) {
    return <div data-testid="wheel-component">Wheel of Surprise</div>
  }
})

describe('DocumentComponent', () => {
  const mockUser = { node_id: 123, title: 'testuser' }
  const mockE2 = { config: {} }

  describe('eager-loaded components', () => {
    it('renders Writeup component for writeup type', () => {
      const data = { type: 'writeup', title: 'Test Writeup' }

      render(<DocumentComponent data={data} user={mockUser} e2={mockE2} />)

      expect(screen.getByTestId('writeup-component')).toBeInTheDocument()
      expect(screen.getByText('Writeup: Test Writeup')).toBeInTheDocument()
    })

    it('renders E2Node component for e2node type', () => {
      const data = { type: 'e2node', title: 'Test Node' }

      render(<DocumentComponent data={data} user={mockUser} e2={mockE2} />)

      expect(screen.getByTestId('e2node-component')).toBeInTheDocument()
      expect(screen.getByText('E2Node: Test Node')).toBeInTheDocument()
    })
  })

  describe('lazy-loaded components', () => {
    it('renders Settings component for settings type', async () => {
      const data = { type: 'settings' }

      render(<DocumentComponent data={data} user={mockUser} e2={mockE2} />)

      await waitFor(() => {
        expect(screen.getByTestId('settings-component')).toBeInTheDocument()
      })
    })

    it('renders Login component for login type', async () => {
      const data = { type: 'login' }

      render(<DocumentComponent data={data} user={mockUser} e2={mockE2} />)

      await waitFor(() => {
        expect(screen.getByTestId('login-component')).toBeInTheDocument()
      })
    })

    it('renders WheelOfSurprise component for wheel_of_surprise type', async () => {
      const data = { type: 'wheel_of_surprise' }

      render(<DocumentComponent data={data} user={mockUser} e2={mockE2} />)

      await waitFor(() => {
        expect(screen.getByTestId('wheel-component')).toBeInTheDocument()
      })
    })
  })

  describe('error handling', () => {
    it('shows error message for unknown document type', () => {
      const data = { type: 'unknown_type_xyz' }

      render(<DocumentComponent data={data} user={mockUser} e2={mockE2} />)

      expect(screen.getByText('Unknown Document Type')).toBeInTheDocument()
      expect(screen.getByText(/unknown_type_xyz/)).toBeInTheDocument()
    })

    it('shows error message for unregistered document type', () => {
      const data = { type: 'not_in_component_map' }

      render(<DocumentComponent data={data} user={mockUser} e2={mockE2} />)

      expect(screen.getByText(/not registered in DocumentComponent router/)).toBeInTheDocument()
    })
  })

  describe('loading state', () => {
    it('shows loading fallback while lazy component loads', async () => {
      // Create a delayed lazy mock
      jest.mock('./Documents/Usergroup', () => {
        return new Promise((resolve) => {
          setTimeout(() => {
            resolve({
              default: function MockUsergroup() {
                return <div data-testid="usergroup-component">Usergroup</div>
              }
            })
          }, 100)
        })
      })

      const data = { type: 'usergroup' }

      render(<DocumentComponent data={data} user={mockUser} e2={mockE2} />)

      // Initially shows loading fallback
      expect(screen.getByText('Loading...')).toBeInTheDocument()
    })
  })

  describe('prop passing', () => {
    it('passes data prop to rendered component', () => {
      const data = { type: 'writeup', title: 'Data Test', node_id: 456 }

      render(<DocumentComponent data={data} user={mockUser} e2={mockE2} />)

      expect(screen.getByText('Writeup: Data Test')).toBeInTheDocument()
    })

    it('passes user prop to rendered component', () => {
      const data = { type: 'e2node', title: 'User Test' }
      const user = { node_id: 789, title: 'specific_user' }

      render(<DocumentComponent data={data} user={user} e2={mockE2} />)

      expect(screen.getByTestId('e2node-component')).toBeInTheDocument()
    })

    it('handles null user prop', () => {
      const data = { type: 'writeup', title: 'No User' }

      render(<DocumentComponent data={data} user={null} e2={mockE2} />)

      expect(screen.getByTestId('writeup-component')).toBeInTheDocument()
    })
  })
})
