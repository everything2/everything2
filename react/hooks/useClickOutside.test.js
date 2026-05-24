import React, { useRef } from 'react'
import { render, fireEvent } from '@testing-library/react'
import { useClickOutside } from './useClickOutside'

const Harness = ({ handler, enabled }) => {
  const ref = useRef(null)
  useClickOutside(ref, handler, enabled)
  return (
    <div>
      <div ref={ref} data-testid="inside">
        <span data-testid="child">child</span>
      </div>
      <div data-testid="outside">outside</div>
    </div>
  )
}

describe('useClickOutside', () => {
  it('fires handler when mousedown lands outside the ref', () => {
    const handler = jest.fn()
    const { getByTestId } = render(<Harness handler={handler} />)

    fireEvent.mouseDown(getByTestId('outside'))
    expect(handler).toHaveBeenCalledTimes(1)
  })

  it('does not fire when mousedown lands inside the ref', () => {
    const handler = jest.fn()
    const { getByTestId } = render(<Harness handler={handler} />)

    fireEvent.mouseDown(getByTestId('inside'))
    expect(handler).not.toHaveBeenCalled()
  })

  it('does not fire when mousedown lands on a descendant of the ref', () => {
    const handler = jest.fn()
    const { getByTestId } = render(<Harness handler={handler} />)

    fireEvent.mouseDown(getByTestId('child'))
    expect(handler).not.toHaveBeenCalled()
  })

  it('does not fire when enabled is false', () => {
    const handler = jest.fn()
    const { getByTestId } = render(<Harness handler={handler} enabled={false} />)

    fireEvent.mouseDown(getByTestId('outside'))
    expect(handler).not.toHaveBeenCalled()
  })

  it('removes its listener on unmount', () => {
    const handler = jest.fn()
    const { unmount, getByTestId } = render(<Harness handler={handler} />)

    fireEvent.mouseDown(getByTestId('outside'))
    expect(handler).toHaveBeenCalledTimes(1)

    unmount()
    fireEvent.mouseDown(document.body)
    expect(handler).toHaveBeenCalledTimes(1)
  })
})
