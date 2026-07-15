import React from 'react'
import { render, waitFor, fireEvent } from '@testing-library/react'
import NodeList from './NodeList'

jest.mock('../LinkNode', () => {
  return function MockLinkNode({ title, node_id, type, className, anchor }) {
    return (
      <a className={className} data-node-id={node_id} data-type={type} data-anchor={anchor}>
        {title}
      </a>
    )
  }
})

// Fully client-resolved (#4537): the five numbered new-nodes Pages are pure gates shipping only
// { type }. NodeList owns the record count + labels (keyed on type) and fetches
// GET /api/newnodes?records=N. notnew arrives as a JSON boolean.
const mockWriteups = [
  { node_id: 1001, parent_id: 2001, parent_title: 'Test E2Node 1', writeuptype: 'idea', publishtime: '2025-11-26 10:00:00', author_id: 3001, author_name: 'alice', notnew: false },
  { node_id: 1002, parent_id: 2002, parent_title: 'Test E2Node 2', writeuptype: 'person', publishtime: '2025-11-26 09:00:00', author_id: 3002, author_name: 'bob', notnew: true }
]
const mockUser = { editor: false }

const mockFetch = (nodelist) => jest.fn(() => Promise.resolve({ json: () => Promise.resolve({ success: 1, nodelist }) }))

beforeEach(() => { global.fetch = mockFetch(mockWriteups) })
afterEach(() => { delete global.fetch; jest.restoreAllMocks() })

describe('NodeList (#4537 fetch-driven)', () => {
  it.each([
    ['25', '25 Most Recent Writeups', 25],
    ['everything_new_nodes', 'Everything New Nodes (100)', 100],
    ['e2n', 'E2N - Everything2 New (200)', 200],
    ['enn', 'ENN - Everything New Nodes (300)', 300],
    ['ekn', 'EKN - Everything Killer Nodes (1024)', 1000]
  ])('type %s renders its config title and fetches records=%s', async (type, title, records) => {
    const { getByText } = render(<NodeList data={{ type }} user={mockUser} />)
    expect(getByText(title)).toBeInTheDocument()               // title is React config, keyed on type
    await waitFor(() => expect(global.fetch).toHaveBeenCalled())
    expect(global.fetch.mock.calls[0][0]).toBe(`/api/newnodes?records=${records}`)
  })

  it('renders the page size selector with the current page selected', async () => {
    const { getByLabelText } = render(<NodeList data={{ type: 'e2n' }} user={mockUser} />)
    const selector = getByLabelText('Show:')
    expect(selector).toBeInTheDocument()
    expect(selector).toHaveValue('E2N')
    await waitFor(() => expect(global.fetch).toHaveBeenCalled())
  })

  it('navigates on dropdown change with no submit button', async () => {
    const { getByLabelText, container } = render(<NodeList data={{ type: 'e2n' }} user={mockUser} />)
    await waitFor(() => expect(global.fetch).toHaveBeenCalled())
    expect(container.querySelector('input[type="submit"]')).toBeNull() // "go" button removed
    fireEvent.change(getByLabelText('Show:'), { target: { value: 'ENN' } })
    expect(window.location.href).toBe('/title/ENN')
  })

  it('renders the fetched writeups (parents, types, authors, dates)', async () => {
    const { getByText, container } = render(<NodeList data={{ type: '25' }} user={mockUser} />)
    await waitFor(() => expect(getByText('Test E2Node 1')).toBeInTheDocument())
    expect(getByText('Test E2Node 2')).toBeInTheDocument()
    expect(container.querySelectorAll('a[href^="/e2node/"]').length).toBeGreaterThanOrEqual(2)
    expect(getByText('(idea)')).toBeInTheDocument()
    expect(getByText('(person)')).toBeInTheDocument()
    expect(getByText('alice')).toBeInTheDocument()
    expect(getByText('bob')).toBeInTheDocument()
    expect(getByText('2025-11-26 10:00:00')).toBeInTheDocument()
  })

  it('does not show hide buttons for non-editors', async () => {
    const { queryByText, getByText } = render(<NodeList data={{ type: '25' }} user={mockUser} />)
    await waitFor(() => expect(getByText('Test E2Node 1')).toBeInTheDocument())
    expect(queryByText('(h?)')).not.toBeInTheDocument()
    expect(queryByText('(un-h!)')).not.toBeInTheDocument()
  })

  it('shows hide/unhide controls for editors, keyed on the boolean notnew', async () => {
    const { getByText } = render(<NodeList data={{ type: '25' }} user={{ editor: true }} />)
    await waitFor(() => expect(getByText('Test E2Node 1')).toBeInTheDocument())
    expect(getByText('(h?)')).toBeInTheDocument()      // notnew=false -> hideable
    expect(getByText('(un-h!)')).toBeInTheDocument()   // notnew=true  -> unhideable
  })

  it('hides a writeup via the hidewriteups API and toggles the row in place (no op= dispatch)', async () => {
    // initial list fetch, then the hide POST returns the new notnew=true
    global.fetch = jest.fn()
      .mockResolvedValueOnce({ json: () => Promise.resolve({ success: 1, nodelist: mockWriteups }) })
      .mockResolvedValueOnce({ json: () => Promise.resolve({ node_id: 1001, notnew: true }) })
    const { getByText, getAllByText } = render(<NodeList data={{ type: '25' }} user={{ editor: true }} />)
    await waitFor(() => expect(getByText('Test E2Node 1')).toBeInTheDocument())

    fireEvent.click(getByText('(h?)'))                 // hide the visible (notnew=false) writeup 1001
    await waitFor(() => expect(global.fetch.mock.calls.length).toBe(2))
    // POSTs to the API endpoint, not a ?op= URL
    expect(global.fetch.mock.calls[1][0]).toBe('/api/hidewriteups/1001/action/hide')
    expect(global.fetch.mock.calls[1][1].method).toBe('POST')
    // row 1001 flipped to hidden -> now offers (un-h!); both rows now show (un-h!)
    await waitFor(() => expect(getAllByText('(un-h!)').length).toBe(2))
  })

  it('renders the empty state when the API returns no writeups', async () => {
    global.fetch = mockFetch([])
    const { getByText } = render(<NodeList data={{ type: '25' }} user={mockUser} />)
    await waitFor(() => expect(getByText('No writeups found.')).toBeInTheDocument())
  })

  it('falls back to the 25 config for an unknown type', async () => {
    const { getByText } = render(<NodeList data={{ type: 'bogus' }} user={mockUser} />)
    expect(getByText('25 Most Recent Writeups')).toBeInTheDocument()
    await waitFor(() => expect(global.fetch.mock.calls[0][0]).toBe('/api/newnodes?records=25'))
  })

  it('renders the Writeups by Type link', async () => {
    const { getByText } = render(<NodeList data={{ type: '25' }} user={mockUser} />)
    await waitFor(() => expect(global.fetch).toHaveBeenCalled())
    expect(getByText('Writeups by Type')).toBeInTheDocument()
  })
})
