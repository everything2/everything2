import React from 'react'
import { render, waitFor } from '@testing-library/react'
import ContentReports from './ContentReports'

// Fully client-resolved (#4511): the Page is a pure gate. ContentReports reads the `driver` selector
// off the URL and fetches GET /api/content_reports (list) or /api/content_reports/:driver (detail),
// which enforces the editor gate. Labels/descriptions are owned by the component, keyed on driver id.

const setSearch = (search) => { window.location.search = search }
const mockFetch = (payload) => jest.fn(() => Promise.resolve({ json: () => Promise.resolve(payload) }))

beforeEach(() => setSearch(''))
afterEach(() => {
  delete global.fetch
  jest.restoreAllMocks()
})

describe('ContentReports list view', () => {
  it('fetches the list endpoint when the URL has no driver, and renders labels + blurb + count', async () => {
    global.fetch = mockFetch({ success: 1, view: 'list', reports: [{ driver: 'editing_writeups_linkless', count: 7 }] })
    const { container } = render(<ContentReports />)
    await waitFor(() => expect(container.textContent).toMatch(/Writeups without links/))
    expect(global.fetch.mock.calls[0][0]).toBe('/api/content_reports')
    expect(container.textContent).toMatch(/These jobs are run on a 24 hour basis/) // LIST_DESCRIPTION
    expect(container.textContent).toMatch(/7/)                                      // backend count
    expect(container.querySelector('a[href*="driver=editing_writeups_linkless"]')).toBeTruthy()
  })

  it('falls back to the driver id if the label map has no entry', async () => {
    global.fetch = mockFetch({ success: 1, view: 'list', reports: [{ driver: 'unknown_driver', count: 0 }] })
    const { container } = render(<ContentReports />)
    await waitFor(() => expect(container.textContent).toMatch(/unknown_driver/))
  })
})

describe('ContentReports driver view', () => {
  it('fetches the driver endpoint from ?driver and renders title + description + nodes', async () => {
    setSearch('?driver=editing_invalid_authors')
    global.fetch = mockFetch({
      success: 1, view: 'driver', driver: 'editing_invalid_authors',
      nodes: [{ node_id: 42, title: 'Some Node', type: 'writeup' }]
    })
    const { container } = render(<ContentReports />)
    await waitFor(() => expect(container.textContent).toMatch(/Invalid Authors on nodes/))
    expect(global.fetch.mock.calls[0][0]).toBe('/api/content_reports/editing_invalid_authors')
    expect(container.textContent).toMatch(/These nodes do not have authors/) // extended_title
    expect(container.querySelector('a[href="/?node_id=42"]')).toBeTruthy()
  })

  it('builds the access error from the flag + driver id (no server copy)', async () => {
    setSearch('?driver=editing_bogus')
    global.fetch = mockFetch({ success: 1, view: 'driver', driver: 'editing_bogus', error: 1 })
    const { container } = render(<ContentReports />)
    await waitFor(() => expect(container.textContent).toMatch(/Could not access driver: editing_bogus/))
  })

  it('renders the node-ref failure copy from a flag', async () => {
    setSearch('?driver=editing_invalid_authors')
    global.fetch = mockFetch({
      success: 1, view: 'driver', driver: 'editing_invalid_authors',
      nodes: [{ node_id: 99, title: '', type: '', error: 1 }]
    })
    const { container } = render(<ContentReports />)
    await waitFor(() => expect(container.textContent).toMatch(/Could not assemble node reference for id: 99/))
  })
})

describe('ContentReports gate', () => {
  it('shows the editors-only message when the API denies (success 0)', async () => {
    global.fetch = mockFetch({ success: 0, error: 'Editors only' })
    const { container } = render(<ContentReports />)
    await waitFor(() => expect(container.textContent).toMatch(/available to editors and administrators/i))
    expect(container.querySelector('.content-reports__table')).toBeNull()
  })

  it('shows a loading state before the fetch resolves', () => {
    global.fetch = jest.fn(() => new Promise(() => {}))
    const { container } = render(<ContentReports />)
    expect(container.textContent).toMatch(/Loading reports/i)
  })
})
