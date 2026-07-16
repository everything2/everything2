import React from 'react'
import { render, waitFor, fireEvent } from '@testing-library/react'
import RecommendationEngine from './RecommendationEngine'

// #4539: one component serves both recommendation documents, keyed on data.type -> signal.
// Fetches /api/recommendations; the form refetches in place (no reload) via history.pushState.

const setLocation = (href) => {
  const u = new URL(href)
  window.location.href = href
  window.location.pathname = u.pathname
  window.location.search = u.search
}
const mockFetch = (payload) => jest.fn(() => Promise.resolve({ json: () => Promise.resolve(payload) }))
const recs = [{ node_id: 42, title: 'A Writeup', parent_title: 'A Node', parent_id: 41, cooled: 3, coolcount: 5 }]

beforeEach(() => setLocation('http://localhost/?node_id=100'))
afterEach(() => { delete global.fetch; jest.restoreAllMocks() })

describe('RecommendationEngine — signal keyed on type (#4539)', () => {
  it('do_you_c_what_i_c fetches signal=cool and shows the cool copy', async () => {
    global.fetch = mockFetch({ success: 0, state: 'no_friends', pronoun: 'You' })
    const { container } = render(<RecommendationEngine data={{ type: 'do_you_c_what_i_c' }} />)
    await waitFor(() => expect(global.fetch).toHaveBeenCalled())
    expect(global.fetch.mock.calls[0][0]).toContain('signal=cool')
    expect(container.querySelector('.do-you-c')).toBeTruthy()
    expect(container.textContent).toMatch(/things you've cooled/i)
  })

  it('the_recommender fetches signal=bookmark and shows the bookmark copy', async () => {
    global.fetch = mockFetch({ success: 0, state: 'no_friends', pronoun: 'You' })
    const { container } = render(<RecommendationEngine data={{ type: 'the_recommender' }} />)
    await waitFor(() => expect(global.fetch).toHaveBeenCalled())
    expect(global.fetch.mock.calls[0][0]).toContain('signal=bookmark')
    expect(container.querySelector('.the-recommender')).toBeTruthy()
    expect(container.textContent).toMatch(/things you've bookmarked/i)
  })

  it('renders recommendations with parent/writeup links and cool count', async () => {
    global.fetch = mockFetch({ success: 1, recommendations: recs, num_signal_sampled: 8, num_friends: 19 })
    const { container } = render(<RecommendationEngine data={{ type: 'do_you_c_what_i_c' }} />)
    await waitFor(() => expect(container.querySelector('.do-you-c__results')).toBeTruthy())
    expect(container.textContent).toMatch(/Based on 8 cooled writeups and 19 similar users/)
    expect(container.querySelector('a[href="/?node_id=41"]')).toBeTruthy()  // parent
    expect(container.querySelector('a[href="/?node_id=42"]')).toBeTruthy()  // writeup
    expect(container.textContent).toMatch(/\[3 C!s\]/)
  })

  it('shows the no_signal cross-ref for cool, plain for bookmark', async () => {
    global.fetch = mockFetch({ success: 0, state: 'no_signal', pronoun: 'You' })
    const { container, rerender } = render(<RecommendationEngine data={{ type: 'do_you_c_what_i_c' }} />)
    await waitFor(() => expect(container.textContent).toMatch(/haven't cooled anything yet/i))
    expect(container.querySelector('a[href="/?node=The+Recommender"]')).toBeTruthy() // cross-ref

    global.fetch = mockFetch({ success: 0, state: 'no_signal', pronoun: 'They' })
    rerender(<RecommendationEngine data={{ type: 'the_recommender' }} />)
    await waitFor(() => expect(container.textContent).toMatch(/haven't bookmarked anything cool yet/i))
  })

  it('shows user_not_found copy from the state flag', async () => {
    setLocation('http://localhost/?node_id=100&cooluser=nobodyzzz')
    global.fetch = mockFetch({ success: 0, state: 'user_not_found', target_username: 'nobodyzzz' })
    const { container } = render(<RecommendationEngine data={{ type: 'do_you_c_what_i_c' }} />)
    await waitFor(() => expect(container.textContent).toMatch(/no 'nobodyzzz' is found/i))
  })
})

describe('RecommendationEngine — in-place search (#4539, no reload)', () => {
  it('submits the form in place: refetches with cooluser, pushes URL, no reload', async () => {
    const pushSpy = jest.spyOn(window.history, 'pushState').mockImplementation(() => {})
    global.fetch = mockFetch({ success: 0, state: 'no_friends', pronoun: 'You' })
    const { container } = render(<RecommendationEngine data={{ type: 'do_you_c_what_i_c' }} />)
    await waitFor(() => expect(container.querySelector('.do-you-c__form')).toBeTruthy())

    fireEvent.change(container.querySelector('input[name="cooluser"]'), { target: { value: 'someuser' } })
    fireEvent.submit(container.querySelector('.do-you-c__form'))
    await waitFor(() => expect(global.fetch.mock.calls.length).toBe(2))

    expect(window.location.href).toBe('http://localhost/?node_id=100') // no hard navigation
    expect(global.fetch.mock.calls[1][0]).toContain('cooluser=someuser')
    expect(global.fetch.mock.calls[1][0]).toContain('signal=cool')
    expect(pushSpy.mock.calls[pushSpy.mock.calls.length - 1][2]).toContain('cooluser=someuser')
  })
})
