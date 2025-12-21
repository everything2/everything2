import React from 'react'
import { render, screen } from '@testing-library/react'
import MasonContent from './MasonContent'

describe('MasonContent', () => {
  beforeEach(() => {
    // Clear any global mock
    delete window.initLegacyContent
  })

  it('renders HTML content via dangerouslySetInnerHTML', () => {
    render(<MasonContent html="<p>Test paragraph</p>" />)
    expect(screen.getByText('Test paragraph')).toBeInTheDocument()
  })

  it('renders complex HTML structure', () => {
    const html = `
      <div class="test-wrapper">
        <h1>Title</h1>
        <p>Paragraph text</p>
        <ul>
          <li>Item 1</li>
          <li>Item 2</li>
        </ul>
      </div>
    `
    render(<MasonContent html={html} />)

    expect(screen.getByText('Title')).toBeInTheDocument()
    expect(screen.getByText('Paragraph text')).toBeInTheDocument()
    expect(screen.getByText('Item 1')).toBeInTheDocument()
    expect(screen.getByText('Item 2')).toBeInTheDocument()
  })

  it('applies mason-content class to container', () => {
    const { container } = render(<MasonContent html="<p>Test</p>" />)
    expect(container.querySelector('.mason-content')).toBeInTheDocument()
  })

  it('handles empty HTML string', () => {
    const { container } = render(<MasonContent html="" />)
    expect(container.querySelector('.mason-content')).toBeInTheDocument()
    expect(container.querySelector('.mason-content').innerHTML).toBe('')
  })

  it('handles undefined HTML', () => {
    const { container } = render(<MasonContent html={undefined} />)
    expect(container.querySelector('.mason-content')).toBeInTheDocument()
  })

  it('calls initLegacyContent when available', () => {
    const initLegacyContent = jest.fn()
    window.initLegacyContent = initLegacyContent

    render(<MasonContent html="<p>Test</p>" />)

    expect(initLegacyContent).toHaveBeenCalled()
    expect(initLegacyContent).toHaveBeenCalledWith(expect.any(HTMLElement))
  })

  it('does not crash when initLegacyContent is not defined', () => {
    // Ensure it's not defined
    delete window.initLegacyContent

    // Should not throw
    render(<MasonContent html="<p>Test</p>" />)
    expect(screen.getByText('Test')).toBeInTheDocument()
  })

  it('re-calls initLegacyContent when html prop changes', () => {
    const initLegacyContent = jest.fn()
    window.initLegacyContent = initLegacyContent

    const { rerender } = render(<MasonContent html="<p>Initial</p>" />)
    expect(initLegacyContent).toHaveBeenCalledTimes(1)

    rerender(<MasonContent html="<p>Updated</p>" />)
    expect(initLegacyContent).toHaveBeenCalledTimes(2)
  })

  it('preserves HTML attributes', () => {
    render(<MasonContent html='<a href="/test" class="test-link">Link</a>' />)
    const link = screen.getByText('Link')
    expect(link).toHaveAttribute('href', '/test')
    expect(link).toHaveClass('test-link')
  })

  it('renders tables correctly', () => {
    const html = `
      <table>
        <thead><tr><th>Header</th></tr></thead>
        <tbody><tr><td>Cell</td></tr></tbody>
      </table>
    `
    render(<MasonContent html={html} />)
    expect(screen.getByText('Header')).toBeInTheDocument()
    expect(screen.getByText('Cell')).toBeInTheDocument()
  })
})
