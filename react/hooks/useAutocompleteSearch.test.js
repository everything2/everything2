import { renderHook, act, waitFor } from '@testing-library/react'
import { useAutocompleteSearch } from './useAutocompleteSearch'

describe('useAutocompleteSearch', () => {
  let consoleErrorSpy

  beforeEach(() => {
    jest.useFakeTimers()
    consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation()
  })

  afterEach(() => {
    jest.useRealTimers()
    jest.clearAllMocks()
    consoleErrorSpy.mockRestore()
  })

  it('does not fire below minLength', () => {
    const search = jest.fn().mockResolvedValue([])
    const { result } = renderHook(() =>
      useAutocompleteSearch({ search, debounceMs: 200, minLength: 2 })
    )

    act(() => {
      result.current.triggerSearch('a')
    })
    act(() => {
      jest.advanceTimersByTime(500)
    })

    expect(search).not.toHaveBeenCalled()
    expect(result.current.results).toEqual([])
  })

  it('debounces rapid keystrokes into one fetch', async () => {
    const search = jest.fn().mockResolvedValue([{ id: 1 }])
    const { result } = renderHook(() =>
      useAutocompleteSearch({ search, debounceMs: 200 })
    )

    act(() => { result.current.triggerSearch('he') })
    act(() => { jest.advanceTimersByTime(50) })
    act(() => { result.current.triggerSearch('hel') })
    act(() => { jest.advanceTimersByTime(50) })
    act(() => { result.current.triggerSearch('hell') })
    act(() => { jest.advanceTimersByTime(50) })
    act(() => { result.current.triggerSearch('hello') })

    expect(search).not.toHaveBeenCalled()

    act(() => { jest.advanceTimersByTime(200) })

    await waitFor(() => expect(search).toHaveBeenCalledTimes(1))
    expect(search.mock.calls[0][0]).toBe('hello')
  })

  it('aborts the prior in-flight request when a new query fires', async () => {
    const aborts = []
    const search = jest.fn().mockImplementation((q, { signal }) => {
      signal.addEventListener('abort', () => aborts.push(q))
      return new Promise(() => {}) // never resolves — we just want to observe the abort
    })

    const { result } = renderHook(() =>
      useAutocompleteSearch({ search, debounceMs: 100 })
    )

    act(() => { result.current.triggerSearch('foo') })
    act(() => { jest.advanceTimersByTime(100) })
    expect(search).toHaveBeenCalledTimes(1)

    act(() => { result.current.triggerSearch('bar') })
    act(() => { jest.advanceTimersByTime(100) })
    expect(search).toHaveBeenCalledTimes(2)

    expect(aborts).toEqual(['foo'])
  })

  it('discards stale responses that resolve after a newer query', async () => {
    // Two queries fire; the FIRST resolves AFTER the second.
    // Without a stale guard, "he" results would clobber "hello" results.
    const resolvers = {}
    const search = jest.fn().mockImplementation((q) =>
      new Promise(resolve => { resolvers[q] = resolve })
    )

    const { result } = renderHook(() =>
      useAutocompleteSearch({ search, debounceMs: 100 })
    )

    act(() => { result.current.triggerSearch('he') })
    act(() => { jest.advanceTimersByTime(100) })

    act(() => { result.current.triggerSearch('hello') })
    act(() => { jest.advanceTimersByTime(100) })

    // Resolve newer one first
    await act(async () => { resolvers['hello']([{ title: 'Hello' }]) })
    expect(result.current.results).toEqual([{ title: 'Hello' }])

    // Then resolve the older one — must NOT clobber
    await act(async () => { resolvers['he']([{ title: 'Old' }]) })
    expect(result.current.results).toEqual([{ title: 'Hello' }])
  })

  it('clears results and cancels pending when below minLength', async () => {
    const search = jest.fn().mockResolvedValue([{ id: 1 }])
    const { result } = renderHook(() =>
      useAutocompleteSearch({ search, debounceMs: 100, minLength: 2 })
    )

    act(() => { result.current.triggerSearch('foo') })
    act(() => { jest.advanceTimersByTime(100) })
    await waitFor(() => expect(result.current.results).toEqual([{ id: 1 }]))

    act(() => { result.current.triggerSearch('') })
    expect(result.current.results).toEqual([])
    expect(result.current.loading).toBe(false)
  })

  it('clearResults() resets state immediately', async () => {
    const search = jest.fn().mockResolvedValue([{ id: 1 }])
    const { result } = renderHook(() =>
      useAutocompleteSearch({ search, debounceMs: 100 })
    )

    act(() => { result.current.triggerSearch('foo') })
    act(() => { jest.advanceTimersByTime(100) })
    await waitFor(() => expect(result.current.results).toEqual([{ id: 1 }]))

    act(() => { result.current.clearResults() })
    expect(result.current.results).toEqual([])
    expect(result.current.loading).toBe(false)
  })

  it('aborts pending fetch on unmount', () => {
    const aborts = []
    const search = jest.fn().mockImplementation((q, { signal }) => {
      signal.addEventListener('abort', () => aborts.push(q))
      return new Promise(() => {})
    })

    const { result, unmount } = renderHook(() =>
      useAutocompleteSearch({ search, debounceMs: 100 })
    )

    act(() => { result.current.triggerSearch('foo') })
    act(() => { jest.advanceTimersByTime(100) })

    unmount()
    expect(aborts).toEqual(['foo'])
  })

  it('swallows AbortError so it does not log to console', async () => {
    const search = jest.fn().mockImplementation(() => {
      const err = new Error('aborted')
      err.name = 'AbortError'
      return Promise.reject(err)
    })

    const { result } = renderHook(() =>
      useAutocompleteSearch({ search, debounceMs: 100 })
    )

    act(() => { result.current.triggerSearch('foo') })
    act(() => { jest.advanceTimersByTime(100) })

    await waitFor(() => expect(search).toHaveBeenCalled())
    expect(consoleErrorSpy).not.toHaveBeenCalled()
  })

  it('logs non-abort errors and clears results', async () => {
    const search = jest.fn().mockRejectedValue(new Error('500 server'))

    const { result } = renderHook(() =>
      useAutocompleteSearch({ search, debounceMs: 100 })
    )

    act(() => { result.current.triggerSearch('foo') })
    act(() => { jest.advanceTimersByTime(100) })

    await waitFor(() => expect(consoleErrorSpy).toHaveBeenCalled())
    expect(result.current.results).toEqual([])
    expect(result.current.loading).toBe(false)
  })
})
