import { useEffect } from 'react'

/**
 * Calls `handler` when a mousedown lands outside `ref.current`.
 *
 * Use for dismissing dropdowns, popovers, and overlays when the user
 * clicks elsewhere on the page. The handler is invoked synchronously
 * during the mousedown phase, so dismissal happens before a downstream
 * click bubbles up.
 *
 * Pass `enabled = false` to detach the listener (e.g., while a modal
 * is closed) without unmounting the component.
 *
 * @param {React.RefObject<HTMLElement>} ref - element whose interior is "inside"
 * @param {(event: MouseEvent) => void} handler - called on outside mousedown
 * @param {boolean} [enabled=true] - whether the listener is attached
 */
export const useClickOutside = (ref, handler, enabled = true) => {
  useEffect(() => {
    if (!enabled) return undefined

    const listener = (event) => {
      const node = ref.current
      if (!node || node.contains(event.target)) return
      handler(event)
    }

    document.addEventListener('mousedown', listener)
    return () => document.removeEventListener('mousedown', listener)
  }, [ref, handler, enabled])
}
