/**
 * Tests for usePolling hook
 */

import { renderHook, act, waitFor } from '@testing-library/react'
import { usePolling } from './usePolling'
import { useActivityDetection } from './useActivityDetection'

// Mock useActivityDetection
jest.mock('./useActivityDetection')

describe('usePolling', () => {
  let mockFetchFunction
  let consoleErrorSpy

  beforeEach(() => {
    jest.useFakeTimers()
    mockFetchFunction = jest.fn()
    consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation()

    // Default: user is active and tab is focused
    useActivityDetection.mockReturnValue({
      isActive: true,
      isMultiTabActive: true
    })

    // Mock document.hidden
    Object.defineProperty(document, 'hidden', {
      configurable: true,
      writable: true,
      value: false
    })
  })

  afterEach(() => {
    jest.useRealTimers()
    jest.clearAllMocks()
    consoleErrorSpy.mockRestore()
  })

  describe('Initial fetch', () => {
    it('fetches data immediately on mount', async () => {
      mockFetchFunction.mockResolvedValue({ message: 'data' })

      const { result } = renderHook(() => usePolling(mockFetchFunction, 5000))

      expect(result.current.loading).toBe(true)
      expect(mockFetchFunction).toHaveBeenCalledTimes(1)

      await waitFor(() => {
        expect(result.current.loading).toBe(false)
      })

      expect(result.current.data).toEqual({ message: 'data' })
      expect(result.current.error).toBeNull()
    })

    it('skips initial fetch when initialData is provided', () => {
      const initialData = { message: 'cached' }

      const { result } = renderHook(() =>
        usePolling(mockFetchFunction, 5000, { initialData })
      )

      expect(result.current.loading).toBe(false)
      expect(result.current.data).toEqual(initialData)
      expect(mockFetchFunction).not.toHaveBeenCalled()
    })

    it('handles fetch errors', async () => {
      mockFetchFunction.mockRejectedValue(new Error('Network error'))

      const { result } = renderHook(() => usePolling(mockFetchFunction, 5000))

      await waitFor(() => {
        expect(result.current.loading).toBe(false)
      })

      expect(result.current.error).toBe('Network error')
      expect(result.current.data).toBeNull()
      expect(consoleErrorSpy).toHaveBeenCalledWith(
        'Polling fetch error:',
        expect.any(Error)
      )
    })
  })

  describe('Polling behavior', () => {
    it('polls at specified interval when user is active', async () => {
      mockFetchFunction.mockResolvedValue({ count: 1 })

      const { result } = renderHook(() => usePolling(mockFetchFunction, 5000))

      // Wait for initial fetch to complete (loading becomes false)
      await waitFor(() => {
        expect(result.current.loading).toBe(false)
      })
      expect(mockFetchFunction).toHaveBeenCalledTimes(1)

      // Now polling interval is active - advance timer
      mockFetchFunction.mockResolvedValue({ count: 2 })
      await act(async () => {
        jest.advanceTimersByTime(5000)
      })

      await waitFor(() => {
        expect(mockFetchFunction).toHaveBeenCalledTimes(2)
      })

      // Advance again
      mockFetchFunction.mockResolvedValue({ count: 3 })
      await act(async () => {
        jest.advanceTimersByTime(5000)
      })

      await waitFor(() => {
        expect(mockFetchFunction).toHaveBeenCalledTimes(3)
      })
    })

    it('stops polling when user becomes inactive', async () => {
      mockFetchFunction.mockResolvedValue({ data: 'test' })

      const { rerender } = renderHook(() => usePolling(mockFetchFunction, 5000))

      await waitFor(() => {
        expect(mockFetchFunction).toHaveBeenCalledTimes(1)
      })

      // User becomes inactive
      useActivityDetection.mockReturnValue({
        isActive: false,
        isMultiTabActive: true
      })
      rerender()

      // Advance timer - should NOT poll
      act(() => {
        jest.advanceTimersByTime(5000)
      })

      expect(mockFetchFunction).toHaveBeenCalledTimes(1)
    })

    it('stops polling when tab loses focus', async () => {
      mockFetchFunction.mockResolvedValue({ data: 'test' })

      const { rerender } = renderHook(() => usePolling(mockFetchFunction, 5000))

      await waitFor(() => {
        expect(mockFetchFunction).toHaveBeenCalledTimes(1)
      })

      // Tab loses focus
      useActivityDetection.mockReturnValue({
        isActive: true,
        isMultiTabActive: false
      })
      rerender()

      // Advance timer - should NOT poll
      act(() => {
        jest.advanceTimersByTime(5000)
      })

      expect(mockFetchFunction).toHaveBeenCalledTimes(1)
    })

    it('resumes polling when user becomes active again', async () => {
      mockFetchFunction.mockResolvedValue({ data: 'test' })

      const { rerender } = renderHook(() => usePolling(mockFetchFunction, 5000))

      await waitFor(() => {
        expect(mockFetchFunction).toHaveBeenCalledTimes(1)
      })

      // User becomes inactive
      useActivityDetection.mockReturnValue({
        isActive: false,
        isMultiTabActive: true
      })
      rerender()

      // Polling should stop
      act(() => {
        jest.advanceTimersByTime(5000)
      })
      expect(mockFetchFunction).toHaveBeenCalledTimes(1)

      // User becomes active again
      useActivityDetection.mockReturnValue({
        isActive: true,
        isMultiTabActive: true
      })
      rerender()

      // Polling should resume
      act(() => {
        jest.advanceTimersByTime(5000)
      })

      await waitFor(() => {
        expect(mockFetchFunction).toHaveBeenCalledTimes(2)
      })
    })

    it('does not poll while loading', async () => {
      // Make fetch take a long time
      mockFetchFunction.mockImplementation(
        () => new Promise(resolve => setTimeout(() => resolve({ data: 'slow' }), 10000))
      )

      renderHook(() => usePolling(mockFetchFunction, 5000))

      expect(mockFetchFunction).toHaveBeenCalledTimes(1)

      // Try to advance timer while still loading
      act(() => {
        jest.advanceTimersByTime(5000)
      })

      // Should not trigger another fetch
      expect(mockFetchFunction).toHaveBeenCalledTimes(1)
    })
  })

  describe('Manual refresh', () => {
    it('refreshes data when refresh is called', async () => {
      mockFetchFunction.mockResolvedValue({ count: 1 })

      const { result } = renderHook(() => usePolling(mockFetchFunction, 5000))

      await waitFor(() => {
        expect(result.current.data).toEqual({ count: 1 })
      })

      mockFetchFunction.mockResolvedValue({ count: 2 })

      act(() => {
        result.current.refresh()
      })

      await waitFor(() => {
        expect(result.current.data).toEqual({ count: 2 })
      })

      expect(mockFetchFunction).toHaveBeenCalledTimes(2)
    })

    it('handles errors in manual refresh', async () => {
      mockFetchFunction.mockResolvedValue({ data: 'initial' })

      const { result } = renderHook(() => usePolling(mockFetchFunction, 5000))

      await waitFor(() => {
        expect(result.current.data).toEqual({ data: 'initial' })
      })

      mockFetchFunction.mockRejectedValue(new Error('Refresh failed'))

      act(() => {
        result.current.refresh()
      })

      await waitFor(() => {
        expect(result.current.error).toBe('Refresh failed')
      })
    })
  })

  describe('Focus refresh', () => {
    it('refreshes when page becomes visible', async () => {
      mockFetchFunction.mockResolvedValue({ data: 'initial' })

      renderHook(() => usePolling(mockFetchFunction, 5000))

      await waitFor(() => {
        expect(mockFetchFunction).toHaveBeenCalledTimes(1)
      })

      mockFetchFunction.mockResolvedValue({ data: 'refreshed' })

      // Simulate page becoming visible
      Object.defineProperty(document, 'hidden', { value: false, writable: true })
      act(() => {
        document.dispatchEvent(new Event('visibilitychange'))
      })

      await waitFor(() => {
        expect(mockFetchFunction).toHaveBeenCalledTimes(2)
      })
    })

    it('does not refresh when page becomes visible if user is inactive', async () => {
      mockFetchFunction.mockResolvedValue({ data: 'test' })

      const { rerender } = renderHook(() => usePolling(mockFetchFunction, 5000))

      await waitFor(() => {
        expect(mockFetchFunction).toHaveBeenCalledTimes(1)
      })

      // User becomes inactive
      useActivityDetection.mockReturnValue({
        isActive: false,
        isMultiTabActive: true
      })
      rerender()

      // Page becomes visible
      Object.defineProperty(document, 'hidden', { value: false, writable: true })
      act(() => {
        document.dispatchEvent(new Event('visibilitychange'))
      })

      // Should not trigger refresh
      expect(mockFetchFunction).toHaveBeenCalledTimes(1)
    })

    it('does not refresh on visibility when refreshOnFocus is false', async () => {
      mockFetchFunction.mockResolvedValue({ data: 'test' })

      renderHook(() => usePolling(mockFetchFunction, 5000, { refreshOnFocus: false }))

      await waitFor(() => {
        expect(mockFetchFunction).toHaveBeenCalledTimes(1)
      })

      // Page becomes visible
      Object.defineProperty(document, 'hidden', { value: false, writable: true })
      act(() => {
        document.dispatchEvent(new Event('visibilitychange'))
      })

      // Should not trigger refresh
      expect(mockFetchFunction).toHaveBeenCalledTimes(1)
    })

    it('does not refresh when page becomes hidden', async () => {
      mockFetchFunction.mockResolvedValue({ data: 'test' })

      renderHook(() => usePolling(mockFetchFunction, 5000))

      await waitFor(() => {
        expect(mockFetchFunction).toHaveBeenCalledTimes(1)
      })

      // Page becomes hidden
      Object.defineProperty(document, 'hidden', { value: true, writable: true })
      act(() => {
        document.dispatchEvent(new Event('visibilitychange'))
      })

      // Should not trigger refresh
      expect(mockFetchFunction).toHaveBeenCalledTimes(1)
    })
  })

  describe('setData', () => {
    it('allows manual data updates', async () => {
      mockFetchFunction.mockResolvedValue({ count: 1 })

      const { result } = renderHook(() => usePolling(mockFetchFunction, 5000))

      await waitFor(() => {
        expect(result.current.data).toEqual({ count: 1 })
      })

      act(() => {
        result.current.setData({ count: 999 })
      })

      expect(result.current.data).toEqual({ count: 999 })
    })
  })

  describe('Cleanup', () => {
    it('clears interval on unmount', async () => {
      mockFetchFunction.mockResolvedValue({ data: 'test' })

      const { unmount } = renderHook(() => usePolling(mockFetchFunction, 5000))

      await waitFor(() => {
        expect(mockFetchFunction).toHaveBeenCalledTimes(1)
      })

      unmount()

      // Advance timer after unmount
      act(() => {
        jest.advanceTimersByTime(5000)
      })

      // Should not call fetch after unmount
      expect(mockFetchFunction).toHaveBeenCalledTimes(1)
    })

    it('removes visibility event listener on unmount', () => {
      const removeEventListenerSpy = jest.spyOn(document, 'removeEventListener')

      const { unmount } = renderHook(() => usePolling(mockFetchFunction, 5000))

      unmount()

      expect(removeEventListenerSpy).toHaveBeenCalledWith(
        'visibilitychange',
        expect.any(Function)
      )

      removeEventListenerSpy.mockRestore()
    })

    it('does not update state after unmount', async () => {
      let resolveFetch
      mockFetchFunction.mockImplementation(
        () => new Promise(resolve => { resolveFetch = resolve })
      )

      const { result, unmount } = renderHook(() => usePolling(mockFetchFunction, 5000))

      expect(result.current.loading).toBe(true)

      unmount()

      // Resolve fetch after unmount
      act(() => {
        resolveFetch({ data: 'late' })
      })

      // Should not cause state update warnings
      await waitFor(() => {
        expect(mockFetchFunction).toHaveBeenCalledTimes(1)
      })
    })
  })

  describe('Custom poll intervals', () => {
    it('uses custom poll interval', async () => {
      mockFetchFunction.mockResolvedValue({ data: 'test' })

      const { result } = renderHook(() => usePolling(mockFetchFunction, 10000)) // 10 seconds

      // Wait for initial fetch to complete
      await waitFor(() => {
        expect(result.current.loading).toBe(false)
      })
      expect(mockFetchFunction).toHaveBeenCalledTimes(1)

      // Advance by 5 seconds - should NOT poll yet
      await act(async () => {
        jest.advanceTimersByTime(5000)
      })
      expect(mockFetchFunction).toHaveBeenCalledTimes(1)

      // Advance by another 5 seconds - NOW should poll
      await act(async () => {
        jest.advanceTimersByTime(5000)
      })

      await waitFor(() => {
        expect(mockFetchFunction).toHaveBeenCalledTimes(2)
      })
    })
  })
})
