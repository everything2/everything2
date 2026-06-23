import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import RepublishModal from './RepublishModal'

// RepublishModal pulls writeuptypes via the useWriteuptypes hook (GET
// /api/writeuptypes) on mount, then POSTs the republish to
// /api/drafts/:id/republish. Both go through global.fetch, so we route by URL.
// On success it redirects via window.location.href (#4198).
describe('RepublishModal (API-backed)', () => {
  const writeuptypes = [
    { node_id: 10, title: 'thing' },
    { node_id: 11, title: 'idea' }
  ]

  const routedFetch = (republishImpl) =>
    (global.fetch = jest.fn((url) => {
      if (String(url).includes('/api/writeuptypes')) {
        return Promise.resolve({ json: async () => ({ success: 1, writeuptypes }) })
      }
      return republishImpl(url)
    }))

  let originalLocation
  beforeEach(() => {
    originalLocation = window.location
    delete window.location
    window.location = { href: '' }
  })
  afterEach(() => {
    window.location = originalLocation
    jest.restoreAllMocks()
  })

  it('renders the modal pre-filled from the draft title', async () => {
    routedFetch(() => Promise.resolve({ json: async () => ({ success: 1 }) }))
    render(<RepublishModal draft={{ node_id: 5, title: 'Some Node (idea)' }} onClose={() => {}} />)

    expect(screen.getByText('Republish Removed Writeup')).toBeInTheDocument()
    // e2node title parsed out of the "title (writeuptype)" form
    expect(screen.getByDisplayValue('Some Node')).toBeInTheDocument()
    // writeuptypes load and the dropdown is populated
    await waitFor(() => expect(screen.getByRole('option', { name: 'idea' })).toBeInTheDocument())
  })

  it('POSTs the republish with the e2node title + selected writeuptype, then redirects', async () => {
    const fetchMock = routedFetch(() =>
      Promise.resolve({ json: async () => ({ success: 1 }) })
    )

    render(<RepublishModal draft={{ node_id: 5, title: 'Some Node (idea)' }} onClose={() => {}} />)

    // wait for writeuptypes so a writeuptype id is selected (matched from title)
    await waitFor(() => expect(screen.getByRole('option', { name: 'idea' })).toBeInTheDocument())

    fireEvent.click(screen.getByRole('button', { name: 'Republish' }))

    await waitFor(() => {
      const post = fetchMock.mock.calls.find(([, o]) => o && o.method === 'POST')
      expect(post).toBeTruthy()
    })

    const post = fetchMock.mock.calls.find(([, o]) => o && o.method === 'POST')
    expect(post[0]).toBe('/api/drafts/5/republish')
    expect(JSON.parse(post[1].body)).toEqual({
      e2node_title: 'Some Node',
      e2node_id: null,
      wrtype_writeuptype: 11 // 'idea' matched from the parsed title
    })

    await waitFor(() =>
      expect(window.location.href).toBe('/title/' + encodeURIComponent('Some Node'))
    )
  })

  it('passes the existing parent_e2node id when the draft has one', async () => {
    const fetchMock = routedFetch(() =>
      Promise.resolve({ json: async () => ({ success: 1 }) })
    )

    render(
      <RepublishModal
        draft={{
          node_id: 7,
          title: 'Orphan (thing)',
          parent_e2node: { node_id: 9001, title: 'Existing Node' }
        }}
        onClose={() => {}}
      />
    )

    await waitFor(() => expect(screen.getByRole('option', { name: 'thing' })).toBeInTheDocument())
    // title input defaults to the parent's title
    expect(screen.getByDisplayValue('Existing Node')).toBeInTheDocument()

    fireEvent.click(screen.getByRole('button', { name: 'Republish' }))

    await waitFor(() => {
      const post = fetchMock.mock.calls.find(([, o]) => o && o.method === 'POST')
      expect(post).toBeTruthy()
    })
    const post = fetchMock.mock.calls.find(([, o]) => o && o.method === 'POST')
    expect(post[0]).toBe('/api/drafts/7/republish')
    expect(JSON.parse(post[1].body)).toEqual({
      e2node_title: 'Existing Node',
      e2node_id: 9001,
      wrtype_writeuptype: 10
    })
  })

  it('surfaces the API error and does not redirect', async () => {
    routedFetch(() =>
      Promise.resolve({ json: async () => ({ success: 0, error: 'Node is locked.' }) })
    )

    render(<RepublishModal draft={{ node_id: 5, title: 'Some Node (idea)' }} onClose={() => {}} />)
    await waitFor(() => expect(screen.getByRole('option', { name: 'idea' })).toBeInTheDocument())

    fireEvent.click(screen.getByRole('button', { name: 'Republish' }))

    await waitFor(() => expect(screen.getByText('Node is locked.')).toBeInTheDocument())
    expect(window.location.href).toBe('')
  })

  it('validates locally: empty title shows an error without POSTing', async () => {
    const fetchMock = routedFetch(() =>
      Promise.resolve({ json: async () => ({ success: 1 }) })
    )

    // draft with no parseable title -> empty default e2node title
    render(<RepublishModal draft={{ node_id: 5, title: '' }} onClose={() => {}} />)
    await waitFor(() => expect(screen.getByRole('option', { name: 'thing' })).toBeInTheDocument())

    // Republish button is disabled while the title is empty; drive handleRepublish
    // through the Enter key path instead.
    const input = screen.getByPlaceholderText(/Enter the e2node title/)
    fireEvent.keyDown(input, { key: 'Enter' })

    await waitFor(() => expect(screen.getByText('Please enter an e2node title')).toBeInTheDocument())
    expect(fetchMock.mock.calls.some(([, o]) => o && o.method === 'POST')).toBe(false)
  })

  it('Escape key invokes onClose', async () => {
    routedFetch(() => Promise.resolve({ json: async () => ({ success: 1 }) }))
    const onClose = jest.fn()
    render(<RepublishModal draft={{ node_id: 5, title: 'Some Node (idea)' }} onClose={onClose} />)

    const input = screen.getByPlaceholderText(/Enter the e2node title/)
    fireEvent.keyDown(input, { key: 'Escape' })
    expect(onClose).toHaveBeenCalled()
  })
})
