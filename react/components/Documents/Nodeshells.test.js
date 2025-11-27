import React from 'react'
import { render } from '@testing-library/react'
import Nodeshells from './Nodeshells'

jest.mock('../LinkNode', () => {
  return function MockLinkNode({ title }) {
    return <span>{title}</span>
  }
})

describe('Nodeshells', () => {
  const mockData = {
    type: 'nodeshells',
    nodeshells: [
      { node_id: 1, title: 'Empty Node 1', createtime: '2025-11-20 10:00:00' },
      { node_id: 2, title: 'Empty Node 2', createtime: '2025-11-21 15:30:00' }
    ]
  }

  it('renders the page title', () => {
    const { getByText } = render(<Nodeshells data={mockData} />)
    expect(getByText('Nodeshells')).toBeInTheDocument()
  })

  it('renders description', () => {
    const { getByText } = render(<Nodeshells data={mockData} />)
    expect(getByText(/empty containers waiting for content/)).toBeInTheDocument()
  })

  it('renders all nodeshells', () => {
    const { getByText } = render(<Nodeshells data={mockData} />)
    expect(getByText('Empty Node 1')).toBeInTheDocument()
    expect(getByText('Empty Node 2')).toBeInTheDocument()
  })

  it('displays count', () => {
    const { getByText } = render(<Nodeshells data={mockData} />)
    expect(getByText('2 nodeshells found')).toBeInTheDocument()
  })

  it('handles singular count', () => {
    const singleData = { type: 'nodeshells', nodeshells: [mockData.nodeshells[0]] }
    const { getByText } = render(<Nodeshells data={singleData} />)
    expect(getByText('1 nodeshell found')).toBeInTheDocument()
  })

  it('handles empty nodeshells array', () => {
    const emptyData = { type: 'nodeshells', nodeshells: [] }
    const { getByText } = render(<Nodeshells data={emptyData} />)
    expect(getByText(/No recent nodeshells found/)).toBeInTheDocument()
  })

  it('renders call to action', () => {
    const { getByText } = render(<Nodeshells data={mockData} />)
    expect(getByText(/Fill a nodeshell!/)).toBeInTheDocument()
  })
})
