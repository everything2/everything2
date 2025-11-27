import React from 'react'
import { render } from '@testing-library/react'
import YourGravatar from './YourGravatar'

describe('YourGravatar', () => {
  const mockData = {
    type: 'your_gravatar',
    gravatars: [
      {
        size: 16,
        urls: [
          { url: 'http://www.gravatar.com/avatar/abc123?s=16', style: 'default' },
          { url: 'http://www.gravatar.com/avatar/abc123?d=identicon&s=16', style: 'identicon' },
          { url: 'http://www.gravatar.com/avatar/abc123?d=monsterid&s=16', style: 'monsterid' },
          { url: 'http://www.gravatar.com/avatar/abc123?d=wavatar&s=16', style: 'wavatar' }
        ]
      },
      {
        size: 32,
        urls: [
          { url: 'http://www.gravatar.com/avatar/abc123?s=32', style: 'default' },
          { url: 'http://www.gravatar.com/avatar/abc123?d=identicon&s=32', style: 'identicon' },
          { url: 'http://www.gravatar.com/avatar/abc123?d=monsterid&s=32', style: 'monsterid' },
          { url: 'http://www.gravatar.com/avatar/abc123?d=wavatar&s=32', style: 'wavatar' }
        ]
      }
    ],
    userEmail: 'test@example.com'
  }

  it('renders the page title', () => {
    const { getByText } = render(<YourGravatar data={mockData} />)
    expect(getByText('Your Gravatar')).toBeInTheDocument()
  })

  it('renders the description paragraph', () => {
    const { getByText } = render(<YourGravatar data={mockData} />)
    expect(
      getByText(/The following shows your gravatar in several different sizes/)
    ).toBeInTheDocument()
  })

  it('renders the email notice', () => {
    const { getByText } = render(<YourGravatar data={mockData} />)
    expect(getByText(/If you have an account at gravatar.com/)).toBeInTheDocument()
  })

  it('renders size labels for each gravatar size', () => {
    const { getByText } = render(<YourGravatar data={mockData} />)
    expect(getByText('16 pixels')).toBeInTheDocument()
    expect(getByText('32 pixels')).toBeInTheDocument()
  })

  it('renders gravatar images for each size and style', () => {
    const { container } = render(<YourGravatar data={mockData} />)
    const images = container.querySelectorAll('img')

    // 2 sizes × 4 styles = 8 images
    expect(images).toHaveLength(8)

    // Check first set (16px)
    expect(images[0]).toHaveAttribute('src', 'http://www.gravatar.com/avatar/abc123?s=16')
    expect(images[0]).toHaveAttribute('alt', 'default style')
    expect(images[1]).toHaveAttribute('src', 'http://www.gravatar.com/avatar/abc123?d=identicon&s=16')
    expect(images[1]).toHaveAttribute('alt', 'identicon style')
  })

  it('renders style labels below each image', () => {
    const { getAllByText } = render(<YourGravatar data={mockData} />)
    // Each style appears twice (once for each size)
    const defaultLabels = getAllByText('default')
    expect(defaultLabels).toHaveLength(2) // 2 sizes with default style
  })

  it('handles empty gravatars array gracefully', () => {
    const emptyData = { type: 'your_gravatar', gravatars: [], userEmail: 'test@example.com' }
    const { container } = render(<YourGravatar data={emptyData} />)

    // Should still render title and description
    expect(container.querySelector('h3')).toHaveTextContent('Your Gravatar')

    // But no images
    expect(container.querySelectorAll('img')).toHaveLength(0)
  })

  it('renders all four styles for each size', () => {
    const { container } = render(<YourGravatar data={mockData} />)

    // Verify all four styles are present as text content
    const styles = ['default', 'identicon', 'monsterid', 'wavatar']
    styles.forEach(style => {
      const styleElements = container.querySelectorAll(`div[style*="font-size: 0.8em"]`)
      const hasStyle = Array.from(styleElements).some(el => el.textContent === style)
      expect(hasStyle).toBe(true)
    })
  })

  it('uses flexbox layout for image grid', () => {
    const { container } = render(<YourGravatar data={mockData} />)
    const firstGrid = container.querySelector('div[style*="display: flex"]')

    expect(firstGrid).toHaveStyle({ display: 'flex', justifyContent: 'center' })
  })
})
