import React from 'react'
import { render, screen } from '@testing-library/react'
import Borgcheck from './Borgcheck'

describe('Borgcheck', () => {
  it('renders nothing when borged is null', () => {
    const { container } = render(<Borgcheck borged={null} currentTime={1000} />)
    expect(container).toBeEmptyDOMElement()
  })

  it('renders nothing when borged is undefined', () => {
    const { container } = render(<Borgcheck currentTime={1000} />)
    expect(container).toBeEmptyDOMElement()
  })

  it('renders nothing when borged is 0', () => {
    const { container } = render(<Borgcheck borged={0} currentTime={1000} />)
    expect(container).toBeEmptyDOMElement()
  })

  describe('when still borged (within cooldown period)', () => {
    it('shows borged message when cooldown not expired (default numborged)', () => {
      // Default numborged=1, so adjustedNum=2, cooldownPeriod = 300 + 60*2 = 420 seconds
      const borgedTime = 1000
      const currentTime = 1100 // Only 100 seconds elapsed, still borged

      render(<Borgcheck borged={borgedTime} currentTime={currentTime} />)

      const link = screen.getByRole('link')
      expect(link).toHaveAttribute('href', "/title/You've Been Borged!")
    })

    it('shows borged message with higher numborged (longer cooldown)', () => {
      // numborged=3, adjustedNum=6, cooldownPeriod = 300 + 60*6 = 660 seconds
      const borgedTime = 1000
      const currentTime = 1500 // 500 seconds elapsed, still under 660

      render(<Borgcheck borged={borgedTime} numborged={3} currentTime={currentTime} />)

      const link = screen.getByRole('link')
      expect(link).toHaveAttribute('href', "/title/You've Been Borged!")
    })
  })

  describe('when released from borg (cooldown expired)', () => {
    it('shows release message when cooldown expired (default numborged)', () => {
      // Default numborged=1, adjustedNum=2, cooldownPeriod = 300 + 60*2 = 420 seconds
      const borgedTime = 1000
      const currentTime = 1500 // 500 seconds elapsed, past 420 cooldown

      render(<Borgcheck borged={borgedTime} currentTime={currentTime} />)

      expect(screen.getByText(/has spit you out/)).toBeInTheDocument()
      const edbLink = screen.getByRole('link')
      expect(edbLink).toHaveAttribute('href', '/title/EDB')
    })

    it('shows release message when cooldown expired (higher numborged)', () => {
      // numborged=3, adjustedNum=6, cooldownPeriod = 300 + 60*6 = 660 seconds
      const borgedTime = 1000
      const currentTime = 2000 // 1000 seconds elapsed, past 660 cooldown

      render(<Borgcheck borged={borgedTime} numborged={3} currentTime={currentTime} />)

      expect(screen.getByText(/has spit you out/)).toBeInTheDocument()
    })
  })

  it('calculates cooldown correctly at boundary', () => {
    // Exactly at cooldown period - should still be borged
    // numborged=1, adjustedNum=2, cooldownPeriod = 420 seconds
    const borgedTime = 1000
    const exactlyAtCooldown = borgedTime + 420 - 1 // 419 seconds, still borged

    render(<Borgcheck borged={borgedTime} numborged={1} currentTime={exactlyAtCooldown} />)

    const link = screen.getByRole('link')
    expect(link).toHaveAttribute('href', "/title/You've Been Borged!")
  })

  it('releases at exactly cooldown period', () => {
    // Exactly at cooldown period - should be released
    const borgedTime = 1000
    const exactlyAtCooldown = borgedTime + 420 // 420 seconds elapsed = cooldown

    render(<Borgcheck borged={borgedTime} numborged={1} currentTime={exactlyAtCooldown} />)

    expect(screen.getByText(/has spit you out/)).toBeInTheDocument()
  })
})
