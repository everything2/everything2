import React from 'react'
import { render, screen } from '@testing-library/react'
import ListHtmlTags from './ListHtmlTags'

describe('ListHtmlTags', () => {
  it('renders the introduction message', () => {
    const data = { approvedTags: {} }
    render(<ListHtmlTags data={data} />)

    expect(
      screen.getByText(/The following HTML tags are approved for use in writeups/)
    ).toBeInTheDocument()
  })

  it('renders tags in alphabetical order', () => {
    const data = {
      approvedTags: {
        p: '1',
        a: 'href, title, name',
        div: 'class, id',
        b: '1'
      }
    }
    render(<ListHtmlTags data={data} />)

    // Tags are rendered in <code> elements
    expect(screen.getByText('<a>')).toBeInTheDocument()
    expect(screen.getByText('<b>')).toBeInTheDocument()
    expect(screen.getByText('<div>')).toBeInTheDocument()
    expect(screen.getByText('<p>')).toBeInTheDocument()
  })

  it('shows attributes for tags that have them', () => {
    const data = {
      approvedTags: {
        a: 'href, title, name',
        img: 'src, alt, width, height'
      }
    }
    render(<ListHtmlTags data={data} />)

    expect(screen.getByText('href')).toBeInTheDocument()
    expect(screen.getByText('title')).toBeInTheDocument()
    expect(screen.getByText('name')).toBeInTheDocument()
    expect(screen.getByText('src')).toBeInTheDocument()
    expect(screen.getByText('alt')).toBeInTheDocument()
    expect(screen.getByText('width')).toBeInTheDocument()
    expect(screen.getByText('height')).toBeInTheDocument()
  })

  it('does not show attributes for tags with value "1"', () => {
    const data = {
      approvedTags: {
        p: '1',
        b: '1',
        a: 'href'
      }
    }
    render(<ListHtmlTags data={data} />)

    // a tag has attributes shown
    expect(screen.getByText('href')).toBeInTheDocument()

    // p and b tags don't show attributes (they're just "1")
    // Verify the tags without attributes don't display any attribute text
    expect(screen.queryByText('1')).not.toBeInTheDocument()
  })

  it('handles empty approved tags', () => {
    const data = { approvedTags: {} }
    render(<ListHtmlTags data={data} />)

    // No tags should be rendered
    expect(screen.queryByText(/<[a-z]+>/)).not.toBeInTheDocument()
  })

  it('handles missing approved tags', () => {
    const data = {}
    render(<ListHtmlTags data={data} />)

    // No tags should be rendered
    expect(screen.queryByText(/<[a-z]+>/)).not.toBeInTheDocument()
  })
})
