import React from 'react'
import { render, fireEvent } from '@testing-library/react'
import WharfingerLinebreaker from './WharfingerLinebreaker'

jest.mock('../LinkNode', () => {
  return function MockLinkNode({ title }) {
    return <span>{title}</span>
  }
})

describe('WharfingerLinebreaker', () => {
  it('renders the title', () => {
    const { getByText } = render(<WharfingerLinebreaker />)
    expect(getByText("What's a \"linebreaker?\"")).toBeInTheDocument()
  })

  it('renders the textarea', () => {
    const { container } = render(<WharfingerLinebreaker />)
    const textarea = container.querySelector('textarea')
    expect(textarea).toBeInTheDocument()
  })

  it('renders Add Break Tags button', () => {
    const { getByText } = render(<WharfingerLinebreaker />)
    expect(getByText('Add Break Tags')).toBeInTheDocument()
  })

  it('renders fixTabs checkbox', () => {
    const { getByLabelText } = render(<WharfingerLinebreaker />)
    const checkbox = getByLabelText(/Replace indenting/)
    expect(checkbox).toBeInTheDocument()
    expect(checkbox).not.toBeChecked()
  })

  it('allows text input', () => {
    const { container } = render(<WharfingerLinebreaker />)
    const textarea = container.querySelector('textarea')

    fireEvent.change(textarea, { target: { value: 'Hello\nWorld' } })
    expect(textarea.value).toBe('Hello\nWorld')
  })

  it('adds br tags to line breaks', () => {
    const { container, getByText } = render(<WharfingerLinebreaker />)
    const textarea = container.querySelector('textarea')

    fireEvent.change(textarea, { target: { value: 'Line 1\nLine 2\nLine 3' } })
    fireEvent.click(getByText('Add Break Tags'))

    expect(textarea.value).toContain('<br />')
  })

  it('handles Windows line endings (\\r\\n)', () => {
    const { container, getByText } = render(<WharfingerLinebreaker />)
    const textarea = container.querySelector('textarea')

    fireEvent.change(textarea, { target: { value: 'Line 1\r\nLine 2' } })
    fireEvent.click(getByText('Add Break Tags'))

    expect(textarea.value).toContain('<br />')
  })

  it('handles Mac line endings (\\r)', () => {
    const { container, getByText } = render(<WharfingerLinebreaker />)
    const textarea = container.querySelector('textarea')

    fireEvent.change(textarea, { target: { value: 'Line 1\rLine 2' } })
    fireEvent.click(getByText('Add Break Tags'))

    expect(textarea.value).toContain('<br />')
  })

  it('removes old br tags before adding new ones', () => {
    const { container, getByText } = render(<WharfingerLinebreaker />)
    const textarea = container.querySelector('textarea')

    fireEvent.change(textarea, { target: { value: 'Line 1<br>\nLine 2\nLine 3' } })
    fireEvent.click(getByText('Add Break Tags'))

    // Check that old <br> was removed and new <br /> added
    expect(textarea.value).not.toContain('<br>')  // Old format removed
    expect(textarea.value).toContain('<br />')     // New format added
    const matches = textarea.value.match(/<br \/>/g)
    expect(matches.length).toBeGreaterThanOrEqual(2)
  })

  it('replaces indents with dd tags when fixTabs enabled', () => {
    const { container, getByText, getByLabelText } = render(<WharfingerLinebreaker />)
    const textarea = container.querySelector('textarea')
    const checkbox = getByLabelText(/Replace indenting/)

    fireEvent.change(textarea, { target: { value: 'Normal\n  Indented' } })
    fireEvent.click(checkbox)
    fireEvent.click(getByText('Add Break Tags'))

    expect(textarea.value).toContain('<dd>')
  })

  it('does not add dd tags when fixTabs disabled', () => {
    const { container, getByText } = render(<WharfingerLinebreaker />)
    const textarea = container.querySelector('textarea')

    fireEvent.change(textarea, { target: { value: 'Normal\n  Indented' } })
    fireEvent.click(getByText('Add Break Tags'))

    expect(textarea.value).not.toContain('<dd>')
  })

  it('renders help text about paragraph tags', () => {
    const { container } = render(<WharfingerLinebreaker />)
    const text = container.textContent
    expect(text).toContain('enclose')
    expect(text).toContain('paragraph')
  })

  it('renders related tool links', () => {
    const { getByText, getAllByText } = render(<WharfingerLinebreaker />)
    expect(getByText('E2 Source Code Formatter')).toBeInTheDocument()
    // E2 Paragraph Tagger appears twice - in prose and in list
    expect(getAllByText('E2 Paragraph Tagger').length).toBeGreaterThanOrEqual(1)
    expect(getByText('E2 List Formatter')).toBeInTheDocument()
  })

  it('preserves non-breaking text', () => {
    const { container, getByText } = render(<WharfingerLinebreaker />)
    const textarea = container.querySelector('textarea')

    const longLine = 'This is a very long line that might wrap in the textarea but has no actual line break character in it'
    fireEvent.change(textarea, { target: { value: longLine } })
    fireEvent.click(getByText('Add Break Tags'))

    // Should not add <br /> to wrapped text, only actual line breaks
    expect(textarea.value).not.toContain('<br />')
  })

  it('removes trailing whitespace', () => {
    const { container, getByText } = render(<WharfingerLinebreaker />)
    const textarea = container.querySelector('textarea')

    fireEvent.change(textarea, { target: { value: 'Line 1   \nLine 2  \t\n' } })
    fireEvent.click(getByText('Add Break Tags'))

    // Should remove trailing spaces/tabs before adding br tags
    expect(textarea.value).toContain('Line 1 <br />')
    expect(textarea.value).toContain('Line 2 <br />')
  })
})
