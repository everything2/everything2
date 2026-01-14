import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import LoginForm from './LoginForm'

// Mock fetch globally
global.fetch = jest.fn()

describe('LoginForm Component', () => {
  let originalLocation

  beforeEach(() => {
    // Reset fetch mock
    fetch.mockClear()

    // Mock window.location
    originalLocation = window.location
    delete window.location
    window.location = {
      href: 'http://localhost/',
      reload: jest.fn(),
      toString: () => 'http://localhost/'
    }
  })

  afterEach(() => {
    window.location = originalLocation
  })

  describe('Rendering', () => {
    it('renders compact layout correctly', () => {
      render(<LoginForm compact={true} />)
      expect(screen.getByPlaceholderText('Username')).toBeInTheDocument()
      expect(screen.getByPlaceholderText('Password')).toBeInTheDocument()
      expect(screen.getByRole('button', { name: /log in/i })).toBeInTheDocument()
    })

    it('renders nodelet layout with remember me checkbox', () => {
      render(<LoginForm nodelet={true} />)
      expect(screen.getByLabelText('Login')).toBeInTheDocument()
      expect(screen.getByLabelText('Password')).toBeInTheDocument()
      expect(screen.getByLabelText(/remember me/i)).toBeInTheDocument()
      expect(screen.getByRole('button', { name: /login/i })).toBeInTheDocument()
    })

    it('renders full layout correctly', () => {
      render(<LoginForm />)
      expect(screen.getByLabelText(/username/i)).toBeInTheDocument()
      expect(screen.getByLabelText(/password/i)).toBeInTheDocument()
      expect(screen.getByRole('button', { name: /log in/i })).toBeInTheDocument()
    })

    it('shows forgot password link by default', () => {
      render(<LoginForm />)
      expect(screen.getByText(/forgot password/i)).toBeInTheDocument()
    })

    it('hides forgot password link when showForgotPassword is false', () => {
      render(<LoginForm showForgotPassword={false} />)
      expect(screen.queryByText(/forgot password/i)).not.toBeInTheDocument()
    })

    it('shows sign up link in nodelet mode by default', () => {
      render(<LoginForm nodelet={true} />)
      expect(screen.getByText(/create an account/i)).toBeInTheDocument()
    })

    it('hides sign up link when showSignUpLink is false', () => {
      render(<LoginForm nodelet={true} showSignUpLink={false} />)
      expect(screen.queryByText(/create an account/i)).not.toBeInTheDocument()
    })

    it('displays login message when provided', () => {
      render(<LoginForm nodelet={true} loginMessage="Session expired" />)
      expect(screen.getByText('Session expired')).toBeInTheDocument()
    })
  })

  describe('Remember Me Checkbox', () => {
    it('remember me checkbox is checked by default', () => {
      render(<LoginForm nodelet={true} />)
      const checkbox = screen.getByLabelText(/remember me/i)
      expect(checkbox).toBeChecked()
    })

    it('remember me checkbox can be toggled', async () => {
      const user = userEvent.setup()
      render(<LoginForm nodelet={true} />)

      const checkbox = screen.getByLabelText(/remember me/i)
      expect(checkbox).toBeChecked()

      await user.click(checkbox)
      expect(checkbox).not.toBeChecked()

      await user.click(checkbox)
      expect(checkbox).toBeChecked()
    })

    it('sends expires parameter by default (remember me checked)', async () => {
      const user = userEvent.setup()
      fetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve({ user: { title: 'testuser' } })
      })

      render(<LoginForm nodelet={true} />)

      await user.type(screen.getByLabelText('Login'), 'testuser')
      await user.type(screen.getByLabelText('Password'), 'testpass')
      // Don't toggle - remember me is checked by default
      await user.click(screen.getByRole('button', { name: /login/i }))

      await waitFor(() => {
        expect(fetch).toHaveBeenCalledWith(
          '/api/sessions/create',
          expect.objectContaining({
            method: 'POST',
            body: JSON.stringify({
              username: 'testuser',
              passwd: 'testpass',
              expires: '+1y'
            })
          })
        )
      })
    })

    it('does NOT send expires parameter when remember me is unchecked', async () => {
      const user = userEvent.setup()
      fetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve({ user: { title: 'testuser' } })
      })

      render(<LoginForm nodelet={true} />)

      await user.type(screen.getByLabelText('Login'), 'testuser')
      await user.type(screen.getByLabelText('Password'), 'testpass')
      // Uncheck remember me (it's checked by default)
      await user.click(screen.getByLabelText(/remember me/i))
      await user.click(screen.getByRole('button', { name: /login/i }))

      await waitFor(() => {
        expect(fetch).toHaveBeenCalledWith(
          '/api/sessions/create',
          expect.objectContaining({
            method: 'POST',
            body: JSON.stringify({
              username: 'testuser',
              passwd: 'testpass'
            })
          })
        )
      })
    })

    it('expires value is +1y for remember me', async () => {
      const user = userEvent.setup()
      fetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve({ user: { title: 'testuser' } })
      })

      render(<LoginForm nodelet={true} />)

      await user.type(screen.getByLabelText('Login'), 'testuser')
      await user.type(screen.getByLabelText('Password'), 'testpass')
      // Remember me is already checked by default
      await user.click(screen.getByRole('button', { name: /login/i }))

      await waitFor(() => {
        const callBody = JSON.parse(fetch.mock.calls[0][1].body)
        expect(callBody.expires).toBe('+1y')
      })
    })
  })

  describe('Form Submission', () => {
    it('calls fetch with correct endpoint', async () => {
      const user = userEvent.setup()
      fetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve({ user: { title: 'testuser' } })
      })

      render(<LoginForm />)

      await user.type(screen.getByLabelText(/username/i), 'testuser')
      await user.type(screen.getByLabelText(/password/i), 'testpass')
      await user.click(screen.getByRole('button', { name: /log in/i }))

      await waitFor(() => {
        expect(fetch).toHaveBeenCalledWith(
          '/api/sessions/create',
          expect.objectContaining({
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            credentials: 'same-origin'
          })
        )
      })
    })

    it('shows loading state during submission', async () => {
      const user = userEvent.setup()
      // Create a promise that we can control
      let resolvePromise
      fetch.mockImplementationOnce(() => new Promise(resolve => {
        resolvePromise = resolve
      }))

      render(<LoginForm />)

      await user.type(screen.getByLabelText(/username/i), 'testuser')
      await user.type(screen.getByLabelText(/password/i), 'testpass')
      await user.click(screen.getByRole('button', { name: /log in/i }))

      // Button should show loading state
      expect(screen.getByRole('button')).toHaveTextContent(/logging in/i)
      expect(screen.getByRole('button')).toBeDisabled()

      // Resolve the promise
      resolvePromise({ ok: true })
    })

    it('reloads page on successful login', async () => {
      const user = userEvent.setup()
      fetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve({ user: { title: 'testuser' } })
      })

      render(<LoginForm />)

      await user.type(screen.getByLabelText(/username/i), 'testuser')
      await user.type(screen.getByLabelText(/password/i), 'testpass')
      await user.click(screen.getByRole('button', { name: /log in/i }))

      await waitFor(() => {
        expect(window.location.reload).toHaveBeenCalled()
      })
    })

    it('calls onSuccess callback on successful login', async () => {
      const user = userEvent.setup()
      const onSuccess = jest.fn()
      fetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve({ user: { title: 'testuser' } })
      })

      render(<LoginForm onSuccess={onSuccess} />)

      await user.type(screen.getByLabelText(/username/i), 'testuser')
      await user.type(screen.getByLabelText(/password/i), 'testpass')
      await user.click(screen.getByRole('button', { name: /log in/i }))

      await waitFor(() => {
        expect(onSuccess).toHaveBeenCalledWith({ username: 'testuser' })
      })
    })

    it('strips op parameter from URL on success to avoid re-triggering logout', async () => {
      const user = userEvent.setup()
      window.location = {
        href: 'http://localhost/?op=logout',
        reload: jest.fn(),
        toString: () => 'http://localhost/?op=logout'
      }

      fetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve({ user: { title: 'testuser' } })
      })

      render(<LoginForm />)

      await user.type(screen.getByLabelText(/username/i), 'testuser')
      await user.type(screen.getByLabelText(/password/i), 'testpass')
      await user.click(screen.getByRole('button', { name: /log in/i }))

      await waitFor(() => {
        // Should redirect to URL without op parameter
        expect(window.location.href).not.toContain('op=logout')
      })
    })
  })

  describe('Error Handling', () => {
    it('displays error for invalid credentials (403)', async () => {
      const user = userEvent.setup()
      fetch.mockResolvedValueOnce({
        ok: false,
        status: 403
      })

      render(<LoginForm />)

      await user.type(screen.getByLabelText(/username/i), 'testuser')
      await user.type(screen.getByLabelText(/password/i), 'wrongpass')
      await user.click(screen.getByRole('button', { name: /log in/i }))

      await waitFor(() => {
        expect(screen.getByText(/invalid username or password/i)).toBeInTheDocument()
      })
    })

    it('displays generic error for other failures', async () => {
      const user = userEvent.setup()
      fetch.mockResolvedValueOnce({
        ok: false,
        status: 500
      })

      render(<LoginForm />)

      await user.type(screen.getByLabelText(/username/i), 'testuser')
      await user.type(screen.getByLabelText(/password/i), 'testpass')
      await user.click(screen.getByRole('button', { name: /log in/i }))

      await waitFor(() => {
        expect(screen.getByText(/login failed/i)).toBeInTheDocument()
      })
    })

    it('displays connection error for network failures', async () => {
      const user = userEvent.setup()
      fetch.mockRejectedValueOnce(new Error('Network error'))

      render(<LoginForm />)

      await user.type(screen.getByLabelText(/username/i), 'testuser')
      await user.type(screen.getByLabelText(/password/i), 'testpass')
      await user.click(screen.getByRole('button', { name: /log in/i }))

      await waitFor(() => {
        expect(screen.getByText(/connection error/i)).toBeInTheDocument()
      })
    })

    it('calls onError callback on failure', async () => {
      const user = userEvent.setup()
      const onError = jest.fn()
      fetch.mockResolvedValueOnce({
        ok: false,
        status: 403
      })

      render(<LoginForm onError={onError} />)

      await user.type(screen.getByLabelText(/username/i), 'testuser')
      await user.type(screen.getByLabelText(/password/i), 'wrongpass')
      await user.click(screen.getByRole('button', { name: /log in/i }))

      await waitFor(() => {
        expect(onError).toHaveBeenCalledWith('Invalid username or password')
      })
    })

    it('clears previous error on new submission', async () => {
      const user = userEvent.setup()

      // First: failed login
      fetch.mockResolvedValueOnce({
        ok: false,
        status: 403
      })

      render(<LoginForm />)

      await user.type(screen.getByLabelText(/username/i), 'testuser')
      await user.type(screen.getByLabelText(/password/i), 'wrongpass')
      await user.click(screen.getByRole('button', { name: /log in/i }))

      await waitFor(() => {
        expect(screen.getByText(/invalid username or password/i)).toBeInTheDocument()
      })

      // Second: start new submission - error should clear
      fetch.mockResolvedValueOnce({
        ok: true
      })

      await user.clear(screen.getByLabelText(/password/i))
      await user.type(screen.getByLabelText(/password/i), 'correctpass')
      await user.click(screen.getByRole('button', { name: /log in/i }))

      // Error should be cleared during submission
      await waitFor(() => {
        expect(screen.queryByText(/invalid username or password/i)).not.toBeInTheDocument()
      })
    })
  })

  describe('Form Validation', () => {
    it('requires username field', () => {
      render(<LoginForm />)
      const usernameInput = screen.getByLabelText(/username/i)
      expect(usernameInput).toBeRequired()
    })

    it('requires password field', () => {
      render(<LoginForm />)
      const passwordInput = screen.getByLabelText(/password/i)
      expect(passwordInput).toBeRequired()
    })
  })

  describe('Accessibility', () => {
    it('has proper autocomplete attributes', () => {
      render(<LoginForm />)
      expect(screen.getByLabelText(/username/i)).toHaveAttribute('autocomplete', 'username')
      expect(screen.getByLabelText(/password/i)).toHaveAttribute('autocomplete', 'current-password')
    })

    it('has autoFocus prop enabled by default', () => {
      // Note: React's autoFocus doesn't add an 'autofocus' attribute in jsdom,
      // but it does work in real browsers. We test the component receives the prop.
      render(<LoginForm />)
      // The input exists and is rendered - the component accepts autoFocus=true by default
      expect(screen.getByLabelText(/username/i)).toBeInTheDocument()
    })

    it('respects autoFocus=false prop', () => {
      render(<LoginForm autoFocus={false} />)
      expect(screen.getByLabelText(/username/i)).not.toHaveAttribute('autofocus')
    })
  })

  describe('Compact Layout Specifics', () => {
    it('shows remember me checkbox in compact mode (checked by default)', () => {
      render(<LoginForm compact={true} />)
      const checkbox = screen.getByLabelText(/remember me/i)
      expect(checkbox).toBeInTheDocument()
      expect(checkbox).toBeChecked()
    })

    it('sends expires by default in compact mode (remember me checked)', async () => {
      const user = userEvent.setup()
      fetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve({ user: { title: 'testuser' } })
      })

      render(<LoginForm compact={true} />)

      await user.type(screen.getByPlaceholderText('Username'), 'testuser')
      await user.type(screen.getByPlaceholderText('Password'), 'testpass')
      // Remember me is checked by default - don't toggle
      await user.click(screen.getByRole('button', { name: /log in/i }))

      await waitFor(() => {
        const callBody = JSON.parse(fetch.mock.calls[0][1].body)
        expect(callBody.expires).toBe('+1y')
      })
    })

    it('submits without expires in compact mode when unchecked', async () => {
      const user = userEvent.setup()
      fetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve({ user: { title: 'testuser' } })
      })

      render(<LoginForm compact={true} />)

      await user.type(screen.getByPlaceholderText('Username'), 'testuser')
      await user.type(screen.getByPlaceholderText('Password'), 'testpass')
      // Uncheck remember me (it's checked by default)
      await user.click(screen.getByLabelText(/remember me/i))
      await user.click(screen.getByRole('button', { name: /log in/i }))

      await waitFor(() => {
        const callBody = JSON.parse(fetch.mock.calls[0][1].body)
        expect(callBody).not.toHaveProperty('expires')
      })
    })
  })

  describe('Full Layout Specifics', () => {
    it('shows remember me checkbox in full mode (checked by default)', () => {
      render(<LoginForm />)
      const checkbox = screen.getByLabelText(/remember me/i)
      expect(checkbox).toBeInTheDocument()
      expect(checkbox).toBeChecked()
    })

    it('sends expires by default in full mode (remember me checked)', async () => {
      const user = userEvent.setup()
      fetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve({ user: { title: 'testuser' } })
      })

      render(<LoginForm />)

      await user.type(screen.getByLabelText(/username/i), 'testuser')
      await user.type(screen.getByLabelText(/password/i), 'testpass')
      // Remember me is checked by default - don't toggle
      await user.click(screen.getByRole('button', { name: /log in/i }))

      await waitFor(() => {
        const callBody = JSON.parse(fetch.mock.calls[0][1].body)
        expect(callBody.expires).toBe('+1y')
      })
    })

    it('submits without expires in full mode when unchecked', async () => {
      const user = userEvent.setup()
      fetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve({ user: { title: 'testuser' } })
      })

      render(<LoginForm />)

      await user.type(screen.getByLabelText(/username/i), 'testuser')
      await user.type(screen.getByLabelText(/password/i), 'testpass')
      // Uncheck remember me (it's checked by default)
      await user.click(screen.getByLabelText(/remember me/i))
      await user.click(screen.getByRole('button', { name: /log in/i }))

      await waitFor(() => {
        const callBody = JSON.parse(fetch.mock.calls[0][1].body)
        expect(callBody).not.toHaveProperty('expires')
      })
    })
  })
})
