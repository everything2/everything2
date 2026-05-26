/**
 * Tests for useActivityDetection. The headline contract here is the #4061
 * multi-tab fix: the hook reports tab visibility (per-tab) instead of "which
 * tab won the most-recent-activity race" (cross-tab via cookie). A future
 * refactor that re-introduces a shared signal would silently kill polling
 * for any non-foreground tab.
 */

import { renderHook, act } from '@testing-library/react'
import { useActivityDetection } from './useActivityDetection'

const setHidden = (hidden) => {
  Object.defineProperty(document, 'hidden', {
    configurable: true,
    writable: true,
    value: hidden
  })
  Object.defineProperty(document, 'visibilityState', {
    configurable: true,
    writable: true,
    value: hidden ? 'hidden' : 'visible'
  })
}

const fireVisibilityChange = () => {
  document.dispatchEvent(new Event('visibilitychange'))
}

describe('useActivityDetection', () => {
  beforeEach(() => {
    setHidden(false)
    // Wipe any cookie the old implementation might have left behind so we can
    // assert the new one never writes one.
    document.cookie.split(';').forEach(c => {
      const name = c.split('=')[0].trim()
      if (name) document.cookie = `${name}=; path=/; expires=Thu, 01 Jan 1970 00:00:01 GMT`
    })
  })

  describe('initial state', () => {
    test('isTabVisible mirrors !document.hidden at mount', () => {
      setHidden(false)
      const visible = renderHook(() => useActivityDetection())
      expect(visible.result.current.isTabVisible).toBe(true)

      setHidden(true)
      const hidden = renderHook(() => useActivityDetection())
      expect(hidden.result.current.isTabVisible).toBe(false)
    })

    test('isActive and isRecentlyActive both start true (assume user is here)', () => {
      const { result } = renderHook(() => useActivityDetection())
      expect(result.current.isActive).toBe(true)
      expect(result.current.isRecentlyActive).toBe(true)
    })
  })

  describe('#4061 regression — visibility, not cookie', () => {
    test('visibilitychange to hidden flips isTabVisible to false', () => {
      const { result } = renderHook(() => useActivityDetection())
      expect(result.current.isTabVisible).toBe(true)

      act(() => {
        setHidden(true)
        fireVisibilityChange()
      })

      expect(result.current.isTabVisible).toBe(false)
    })

    test('visibilitychange back to visible flips isTabVisible to true', () => {
      setHidden(true)
      const { result } = renderHook(() => useActivityDetection())
      expect(result.current.isTabVisible).toBe(false)

      act(() => {
        setHidden(false)
        fireVisibilityChange()
      })

      expect(result.current.isTabVisible).toBe(true)
    })

    test('user activity does NOT write a cookie (the old "last active tab wins" heuristic)', () => {
      // Pin the contract that broke #4061: any cookie write here means a future
      // change has re-introduced the cross-tab signal and one tab will silently
      // mute the others.
      renderHook(() => useActivityDetection())
      const cookieBefore = document.cookie

      act(() => {
        window.dispatchEvent(new MouseEvent('mousedown'))
        window.dispatchEvent(new KeyboardEvent('keydown'))
        window.dispatchEvent(new Event('scroll'))
      })

      expect(document.cookie).toBe(cookieBefore)
      expect(document.cookie).not.toContain('lastActiveWindow')
    })

    test('two independent hook instances both report visible when the tab is visible', () => {
      // The old cookie heuristic would have one instance "win" and the other
      // would flip to false on the next 5s tick. Visibility is per-tab, so
      // multiple consumers within the same tab both see true.
      setHidden(false)
      const a = renderHook(() => useActivityDetection())
      const b = renderHook(() => useActivityDetection())

      expect(a.result.current.isTabVisible).toBe(true)
      expect(b.result.current.isTabVisible).toBe(true)
    })
  })
})
