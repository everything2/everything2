import React from 'react'
import { render, screen } from '@testing-library/react'
import StaffOnly from './StaffOnly'

// Soft per-scheme gate result (#4497): a gated Page returns a blank { type: 'staff_only' } payload
// and this owns the friendly copy — the server ships no "Access denied…" string.
describe('StaffOnly soft-gate page', () => {
  it('renders the friendly editors/admins message with no server-supplied text', () => {
    render(<StaffOnly data={{}} />)
    expect(screen.getByText(/editors and administrators/i)).toBeInTheDocument()
  })
})
