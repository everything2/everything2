import React from 'react'
import { render } from '@testing-library/react'
import EverythingObscureWriteups from './EverythingObscureWriteups'

// Mock LinkNode
jest.mock('../LinkNode', () => {
  return function MockLinkNode({ title }) {
    return <span>{title}</span>
  }
})

describe('EverythingObscureWriteups', () => {
  const mockData = {
    type: 'everything_s_obscure_writeups',
    writeups: [
      {
        node_id: 1,
        title: 'Obscure Writeup 1',
        parent_title: 'Parent Node 1',
        author: 'Alice',
        author_id: 10
      },
      {
        node_id: 2,
        title: 'Obscure Writeup 2',
        parent_title: 'Obscure Writeup 2', // Same as title - no parent
        author: 'Bob',
        author_id: 20
      }
    ]
  }

  it('renders the page title', () => {
    const { getByText } = render(<EverythingObscureWriteups data={mockData} />)
    expect(getByText("Everything's Obscure Writeups")).toBeInTheDocument()
  })

  it('renders description', () => {
    const { getByText } = render(<EverythingObscureWriteups data={mockData} />)
    expect(getByText(/zero reputation/)).toBeInTheDocument()
  })

  it('renders all writeups', () => {
    const { getByText } = render(<EverythingObscureWriteups data={mockData} />)
    expect(getByText('"Obscure Writeup 1"')).toBeInTheDocument()
    expect(getByText('"Obscure Writeup 2"')).toBeInTheDocument()
  })

  it('renders author names', () => {
    const { getByText } = render(<EverythingObscureWriteups data={mockData} />)
    expect(getByText('Alice')).toBeInTheDocument()
    expect(getByText('Bob')).toBeInTheDocument()
  })

  it('handles empty writeups array', () => {
    const emptyData = { type: 'everything_s_obscure_writeups', writeups: [] }
    const { getByText } = render(<EverythingObscureWriteups data={emptyData} />)
    
    expect(getByText(/No obscure writeups found/)).toBeInTheDocument()
  })

  it('renders tip box', () => {
    const { getByText } = render(<EverythingObscureWriteups data={mockData} />)
    expect(getByText(/Tip:/)).toBeInTheDocument()
    expect(getByText(/randomly selected/)).toBeInTheDocument()
  })
})
