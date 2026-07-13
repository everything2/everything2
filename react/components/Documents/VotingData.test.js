import React from 'react'
import { render, waitFor, fireEvent } from '@testing-library/react'
import VotingData from './VotingData'

// Fully client-resolved (#4530): the Page is a pure gate. VotingData fetches GET /api/voting_data
// (admin-gated) on mount, reading voteday/voteday2/votemonth/voteyear off the URL. Both search forms
// submit IN PLACE (no reload), syncing the URL via history.pushState.

const setLocation = (href) => {
  const u = new URL(href)
  window.location.href = href
  window.location.pathname = u.pathname
  window.location.search = u.search
}
const mockFetch = (payload) => jest.fn(() => Promise.resolve({ json: () => Promise.resolve(payload) }))

beforeEach(() => { setLocation('http://localhost/?node_id=1877984'); window.e2 = { node_id: 1877984 } })
afterEach(() => { delete global.fetch; delete window.e2; jest.restoreAllMocks() })

describe('VotingData — fetch + admin gate (#4530)', () => {
  it('renders the admin error when the API refuses', async () => {
    global.fetch = mockFetch({ success: 0, state: 'admin' })
    const { container } = render(<VotingData />)
    await waitFor(() => expect(container.textContent).toMatch(/restricted to administrators/i))
  })

  it('renders a date-range result', async () => {
    setLocation('http://localhost/?node_id=1877984&voteday=2020-01-01')
    global.fetch = mockFetch({
      success: 1, search_type: 'date_range',
      results: [{ start_date: '2020-01-01', end_date: '2020-01-01', count: 4321 }]
    })
    const { container } = render(<VotingData />)
    await waitFor(() => expect(container.querySelector('.voting-data__result-box')).toBeTruthy())
    expect(container.textContent).toMatch(/4,321 votes/)
    expect(container.textContent).toMatch(/on 2020-01-01/)
  })

  it('renders a monthly breakdown with a total', async () => {
    setLocation('http://localhost/?node_id=1877984&votemonth=1&voteyear=2020')
    global.fetch = mockFetch({
      success: 1, search_type: 'monthly',
      results: [
        { date: '2020-01-01', count: 10 },
        { date: '2020-01-02', count: 20 }
      ]
    })
    const { container } = render(<VotingData />)
    await waitFor(() => expect(container.querySelector('.voting-data__table')).toBeTruthy())
    expect(container.textContent).toMatch(/Monthly Breakdown/)
    expect(container.textContent).toMatch(/Total/)
    expect(container.textContent).toMatch(/30/) // 10 + 20
  })
})

describe('VotingData — in-place search (#4530, no reload)', () => {
  it('submits the date-range search in place: refetches voteday, pushes URL, no reload', async () => {
    const pushSpy = jest.spyOn(window.history, 'pushState').mockImplementation(() => {})
    global.fetch = mockFetch({ success: 1, search_type: '', results: [] })
    const { container, getByText } = render(<VotingData />)
    await waitFor(() => expect(container.querySelector('input[name="voteday"]')).toBeTruthy())

    fireEvent.change(container.querySelector('input[name="voteday"]'), { target: { value: '2021-05-05' } })
    fireEvent.click(getByText(/Search date range/))
    await waitFor(() => expect(global.fetch.mock.calls.length).toBe(2))

    expect(window.location.href).toBe('http://localhost/?node_id=1877984') // no hard navigation
    expect(global.fetch.mock.calls[1][0]).toContain('voteday=2021-05-05')
    expect(pushSpy.mock.calls[pushSpy.mock.calls.length - 1][2]).toContain('voteday=2021-05-05')
  })

  it('submits the monthly search in place: refetches month+year, no reload', async () => {
    global.fetch = mockFetch({ success: 1, search_type: '', results: [] })
    const { container, getByText } = render(<VotingData />)
    await waitFor(() => expect(container.querySelector('input[name="votemonth"]')).toBeTruthy())

    fireEvent.change(container.querySelector('input[name="voteyear"]'), { target: { value: '2021' } })
    fireEvent.change(container.querySelector('input[name="votemonth"]'), { target: { value: '5' } })
    fireEvent.click(getByText(/Search month/))
    await waitFor(() => expect(global.fetch.mock.calls.length).toBe(2))

    expect(window.location.href).toBe('http://localhost/?node_id=1877984')
    expect(global.fetch.mock.calls[1][0]).toContain('votemonth=5')
    expect(global.fetch.mock.calls[1][0]).toContain('voteyear=2021')
  })
})
