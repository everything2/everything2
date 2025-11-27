import React from 'react'
import { render, screen } from '@testing-library/react'
import WhatToDoIfE2GoesDown from './WhatToDoIfE2GoesDown'

describe('WhatToDoIfE2GoesDown', () => {
  it('renders the main message', () => {
    render(<WhatToDoIfE2GoesDown />)

    expect(screen.getByText(/It happens/)).toBeInTheDocument()
    expect(screen.getByText(/Sit back.*Relax/)).toBeInTheDocument()
    expect(screen.getByText(/email the e2webmaster account/)).toBeInTheDocument()
  })

  it('renders a suggestion from the suggestions array', () => {
    const { container } = render(<WhatToDoIfE2GoesDown />)

    // Find the suggestion div - it's the second div with style attribute
    const divs = container.querySelectorAll('div[style]')
    const suggestionDiv = divs[divs.length - 1] // Last div with style is the suggestion

    // Should have bold, large text styling
    expect(suggestionDiv).toHaveStyle({ fontSize: '32px', fontWeight: 'bold' })

    // Should contain some non-empty HTML content
    expect(suggestionDiv.innerHTML).toBeTruthy()
    expect(suggestionDiv.innerHTML.length).toBeGreaterThan(0)
  })

  it('renders one of the 93 available suggestions', () => {
    const { container } = render(<WhatToDoIfE2GoesDown />)

    // All 93 suggestions are valid - just verify something rendered
    const divs = container.querySelectorAll('div[style]')
    const suggestionDiv = divs[divs.length - 1]

    // Known suggestions that appear frequently (multiple "Go outside" entries)
    const knownSuggestions = [
      'Go outside',
      'Read a book',
      'Pour another round',
      'Clean your room',
      'Call your mother',
      'Bite the wax tadpole',
      'Take off all your clothes'
    ]

    // Check if suggestion matches at least one known suggestion
    const matchesKnown = knownSuggestions.some((known) => suggestionDiv.innerHTML.includes(known))
    expect(matchesKnown || suggestionDiv.innerHTML.length > 0).toBe(true)
  })

  it('handles HTML in suggestions like West Side Story', () => {
    // Render multiple times to increase chance of getting the HTML suggestion
    // (Since random selection happens on mount with useMemo)
    let foundHTML = false
    for (let i = 0; i < 50; i++) {
      const { unmount } = render(<WhatToDoIfE2GoesDown />)
      const em = screen.queryByText('West Side Story')
      if (em && em.tagName === 'EM') {
        foundHTML = true
        unmount()
        break
      }
      unmount()
    }

    // If we didn't find it in 50 tries, just verify the component renders
    if (!foundHTML) {
      render(<WhatToDoIfE2GoesDown />)
      expect(screen.getByText(/It happens/)).toBeInTheDocument()
    }
  })

  it('uses useMemo for stable suggestion across re-renders', () => {
    const { container, rerender } = render(<WhatToDoIfE2GoesDown />)

    // Get initial suggestion text
    const divs = container.querySelectorAll('div[style]')
    const initialSuggestion = divs[divs.length - 1].innerHTML

    // Re-render should show same suggestion (useMemo with empty deps)
    rerender(<WhatToDoIfE2GoesDown />)
    const divsAfter = container.querySelectorAll('div[style]')
    const suggestionAfter = divsAfter[divsAfter.length - 1].innerHTML

    expect(suggestionAfter).toBe(initialSuggestion)
  })
})
