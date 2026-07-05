import React from 'react'
import { render, screen } from '@testing-library/react'
import E2Node from './E2Node'

// E2Node is the core e2node page wrapper. Its own logic is the guard branches
// (loading / not-found) and the category_id URL param it forwards to the heavy
// E2NodeDisplay child. We mock that child so this stays a unit test of E2Node's
// own responsibilities, not a full e2node render.
jest.mock('../E2NodeDisplay', () => (props) => (
  <div data-testid="e2node-display" data-focused-category={String(props.focusedCategoryId)}>
    {props.e2node?.title}
  </div>
))

// jsdom's history.replaceState doesn't reflect into location.search here, so
// override window.location directly to exercise the category_id read.
function withSearch(search, fn) {
  const orig = window.location
  Object.defineProperty(window, 'location', { value: { ...orig, search }, writable: true, configurable: true })
  try {
    fn()
  } finally {
    Object.defineProperty(window, 'location', { value: orig, writable: true, configurable: true })
  }
}

describe('E2Node', () => {
  it('shows a loading placeholder when data is missing', () => {
    render(<E2Node data={null} user={{}} />)
    expect(screen.getByText('Loading...')).toBeInTheDocument()
  })

  it('shows a not-found error when there is no e2node in the data', () => {
    render(<E2Node data={{ e2node: null }} user={{}} />)
    expect(screen.getByText('E2node not found')).toBeInTheDocument()
  })

  it('renders the display child with the e2node when present', () => {
    render(<E2Node data={{ e2node: { title: 'Real Node', node_id: 5 } }} user={{}} />)
    const child = screen.getByTestId('e2node-display')
    expect(child).toHaveTextContent('Real Node')
    // no category_id in the URL -> focusedCategoryId is null
    expect(child).toHaveAttribute('data-focused-category', 'null')
  })

  it('forwards a category_id URL param to the display child as an integer', () => {
    withSearch('?category_id=123', () => {
      render(<E2Node data={{ e2node: { title: 'Real Node', node_id: 5 } }} user={{}} />)
      expect(screen.getByTestId('e2node-display')).toHaveAttribute('data-focused-category', '123')
    })
  })
})
