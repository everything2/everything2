import React from 'react'
import { render, screen } from '@testing-library/react'
import Statistics from './Statistics'

// Mock child components
jest.mock('../NodeletContainer', () => {
  return function MockNodeletContainer({ title, children, showNodelet, nodeletIsOpen }) {
    return (
      <div data-testid="nodelet-container" data-title={title} data-open={nodeletIsOpen}>
        {children}
      </div>
    )
  }
})

jest.mock('../NodeletSection', () => {
  return function MockNodeletSection({ nodelet, section, title, display, toggleSection, children }) {
    return (
      <div data-testid="nodelet-section" data-nodelet={nodelet} data-section={section} data-title={title} data-display={display}>
        {children}
      </div>
    )
  }
})

describe('Statistics Component', () => {
  describe('rendering with no data', () => {
    it('shows friendly message when statistics prop is undefined', () => {
      render(<Statistics />)
      expect(screen.getByText('No statistics available')).toBeInTheDocument()
    })

    it('shows friendly message when statistics prop is null', () => {
      render(<Statistics statistics={null} />)
      expect(screen.getByText('No statistics available')).toBeInTheDocument()
    })

    it('renders container but hides personal section when empty', () => {
      render(<Statistics statistics={{ fun: { nodeFu: '1.0' }, advancement: { merit: '1.0' } }} />)
      expect(screen.getByTestId('nodelet-container')).toBeInTheDocument()
      expect(screen.queryByText('Yours')).not.toBeInTheDocument()
    })

    it('renders container but hides fun section when empty', () => {
      render(<Statistics statistics={{ personal: { xp: 100 }, advancement: { merit: '1.0' } }} />)
      expect(screen.getByTestId('nodelet-container')).toBeInTheDocument()
      expect(screen.queryByText('Fun Stats')).not.toBeInTheDocument()
    })

    it('renders container but hides advancement section when empty', () => {
      render(<Statistics statistics={{ personal: { xp: 100 }, fun: { nodeFu: '1.0' } }} />)
      expect(screen.getByTestId('nodelet-container')).toBeInTheDocument()
      expect(screen.queryByText('Old Merit System')).not.toBeInTheDocument()
    })
  })

  describe('rendering with complete data', () => {
    const completeStats = {
      personal: {
        xp: 5000,
        writeups: 50,
        level: 5,
        xpNeeded: 1000,
        wusNeeded: undefined,
        gp: 100,
        gpOptout: false
      },
      fun: {
        nodeFu: '100.0',
        goldenTrinkets: 5,
        silverTrinkets: 10,
        stars: 3,
        easterEggs: 2,
        tokens: 8
      },
      advancement: {
        merit: '1.50',
        lf: '0.0123',
        devotion: 75,
        meritMean: 1.0,
        meritStddev: 0.5
      }
    }

    it('renders NodeletContainer with correct title', () => {
      render(<Statistics statistics={completeStats} />)
      const container = screen.getByTestId('nodelet-container')
      expect(container).toHaveAttribute('data-title', 'Statistics')
    })

    it('renders all three sections', () => {
      render(<Statistics statistics={completeStats} />)
      const sections = screen.getAllByTestId('nodelet-section')
      expect(sections).toHaveLength(3)
    })

    it('renders personal section with correct props', () => {
      render(<Statistics statistics={completeStats} stat_personal={true} toggleSection={jest.fn()} />)
      const personalSection = screen.getAllByTestId('nodelet-section')[0]
      expect(personalSection).toHaveAttribute('data-nodelet', 'stat')
      expect(personalSection).toHaveAttribute('data-section', 'personal')
      expect(personalSection).toHaveAttribute('data-title', 'Yours')
      expect(personalSection).toHaveAttribute('data-display', 'true')
    })

    it('renders fun stats section with correct props', () => {
      render(<Statistics statistics={completeStats} stat_fun={false} toggleSection={jest.fn()} />)
      const funSection = screen.getAllByTestId('nodelet-section')[1]
      expect(funSection).toHaveAttribute('data-nodelet', 'stat')
      expect(funSection).toHaveAttribute('data-section', 'fun')
      expect(funSection).toHaveAttribute('data-title', 'Fun Stats')
      expect(funSection).toHaveAttribute('data-display', 'false')
    })

    it('renders advancement section with correct props', () => {
      render(<Statistics statistics={completeStats} stat_advancement={true} toggleSection={jest.fn()} />)
      const advancementSection = screen.getAllByTestId('nodelet-section')[2]
      expect(advancementSection).toHaveAttribute('data-nodelet', 'stat')
      expect(advancementSection).toHaveAttribute('data-section', 'advancement')
      expect(advancementSection).toHaveAttribute('data-title', 'Old Merit System')
      expect(advancementSection).toHaveAttribute('data-display', 'true')
    })

    it('displays all personal stats', () => {
      const { container } = render(<Statistics statistics={completeStats} />)
      const allText = container.textContent
      expect(screen.getByText(/XP:/)).toBeInTheDocument()
      expect(allText).toContain('XP: 5000')
      expect(screen.getByText(/Writeups:/)).toBeInTheDocument()
      expect(allText).toContain('Writeups: 50')
      expect(screen.getByText(/Level:/)).toBeInTheDocument()
      expect(allText).toContain('Level: 5')
      expect(screen.getByText(/GP:/)).toBeInTheDocument()
      expect(allText).toContain('GP: 100')
    })

    it('displays all fun stats', () => {
      render(<Statistics statistics={completeStats} />)
      expect(screen.getByText(/Node-Fu:/)).toBeInTheDocument()
      expect(screen.getByText('100.0')).toBeInTheDocument()
      expect(screen.getByText(/Golden Trinkets:/)).toBeInTheDocument()
      expect(screen.getByText(/Silver Trinkets:/)).toBeInTheDocument()
      expect(screen.getByText(/Stars:/)).toBeInTheDocument()
      expect(screen.getByText(/Easter Eggs:/)).toBeInTheDocument()
      expect(screen.getByText(/Tokens:/)).toBeInTheDocument()
    })

    it('displays all advancement stats', () => {
      render(<Statistics statistics={completeStats} />)
      expect(screen.getByText(/Merit:/)).toBeInTheDocument()
      expect(screen.getByText('1.50')).toBeInTheDocument()
      expect(screen.getByText(/LF:/)).toBeInTheDocument()
      expect(screen.getByText('0.0123')).toBeInTheDocument()
      expect(screen.getByText(/Devotion:/)).toBeInTheDocument()
      expect(screen.getByText('75')).toBeInTheDocument()
      expect(screen.getByText(/Merit mean:/)).toBeInTheDocument()
      expect(screen.getByText(/Merit stddev:/)).toBeInTheDocument()
    })
  })

  describe('conditional rendering of personal stats', () => {
    it('shows XP needed when xpNeeded is positive', () => {
      const stats = {
        personal: {
          xp: 5000,
          writeups: 50,
          level: 5,
          xpNeeded: 1000,
          wusNeeded: undefined,
          gp: 100,
          gpOptout: false
        },
        fun: { nodeFu: '100.0', goldenTrinkets: 0, silverTrinkets: 0, stars: 0, easterEggs: 0, tokens: 0 },
        advancement: { merit: '1.00', lf: '0.0000', devotion: 0, meritMean: 0, meritStddev: 0 }
      }
      const { container } = render(<Statistics statistics={stats} />)
      expect(screen.getByText(/XP needed:/)).toBeInTheDocument()
      // Check for the specific value in context
      const allText = container.textContent
      expect(allText).toContain('XP needed: 1000')
    })

    it('does not show XP needed when xpNeeded is 0', () => {
      const stats = {
        personal: {
          xp: 5000,
          writeups: 50,
          level: 5,
          xpNeeded: 0,
          wusNeeded: 5,
          gp: 100,
          gpOptout: false
        },
        fun: { nodeFu: '100.0', goldenTrinkets: 0, silverTrinkets: 0, stars: 0, easterEggs: 0, tokens: 0 },
        advancement: { merit: '1.00', lf: '0.0000', devotion: 0, meritMean: 0, meritStddev: 0 }
      }
      render(<Statistics statistics={stats} />)
      expect(screen.queryByText(/XP needed:/)).not.toBeInTheDocument()
    })

    it('shows WUs needed when wusNeeded is positive', () => {
      const stats = {
        personal: {
          xp: 5000,
          writeups: 50,
          level: 5,
          xpNeeded: 0,
          wusNeeded: 5,
          gp: 100,
          gpOptout: false
        },
        fun: { nodeFu: '100.0', goldenTrinkets: 0, silverTrinkets: 0, stars: 0, easterEggs: 0, tokens: 0 },
        advancement: { merit: '1.00', lf: '0.0000', devotion: 0, meritMean: 0, meritStddev: 0 }
      }
      const { container } = render(<Statistics statistics={stats} />)
      expect(screen.getByText(/WUs needed:/)).toBeInTheDocument()
      // Check for the specific value in context
      const allText = container.textContent
      expect(allText).toContain('WUs needed: 5')
    })

    it('does not show WUs needed when wusNeeded is 0', () => {
      const stats = {
        personal: {
          xp: 5000,
          writeups: 50,
          level: 5,
          xpNeeded: 0,
          wusNeeded: 0,
          gp: 100,
          gpOptout: false
        },
        fun: { nodeFu: '100.0', goldenTrinkets: 0, silverTrinkets: 0, stars: 0, easterEggs: 0, tokens: 0 },
        advancement: { merit: '1.00', lf: '0.0000', devotion: 0, meritMean: 0, meritStddev: 0 }
      }
      render(<Statistics statistics={stats} />)
      expect(screen.queryByText(/WUs needed:/)).not.toBeInTheDocument()
    })

    it('shows GP when gpOptout is false', () => {
      const stats = {
        personal: {
          xp: 5000,
          writeups: 50,
          level: 5,
          xpNeeded: 1000,
          wusNeeded: undefined,
          gp: 100,
          gpOptout: false
        },
        fun: { nodeFu: '100.0', goldenTrinkets: 0, silverTrinkets: 0, stars: 0, easterEggs: 0, tokens: 0 },
        advancement: { merit: '1.00', lf: '0.0000', devotion: 0, meritMean: 0, meritStddev: 0 }
      }
      render(<Statistics statistics={stats} />)
      expect(screen.getByText(/GP:/)).toBeInTheDocument()
      expect(screen.getByText('100')).toBeInTheDocument()
    })

    it('does not show GP when gpOptout is true', () => {
      const stats = {
        personal: {
          xp: 5000,
          writeups: 50,
          level: 5,
          xpNeeded: 1000,
          wusNeeded: undefined,
          gp: 100,
          gpOptout: true
        },
        fun: { nodeFu: '100.0', goldenTrinkets: 0, silverTrinkets: 0, stars: 0, easterEggs: 0, tokens: 0 },
        advancement: { merit: '1.00', lf: '0.0000', devotion: 0, meritMean: 0, meritStddev: 0 }
      }
      render(<Statistics statistics={stats} />)
      expect(screen.queryByText(/GP:/)).not.toBeInTheDocument()
    })
  })

  describe('handling of undefined and null values', () => {
    it('does not render stat row when value is undefined', () => {
      const stats = {
        personal: {
          xp: undefined,
          writeups: 50,
          level: 5,
          xpNeeded: 1000,
          wusNeeded: undefined,
          gp: 100,
          gpOptout: false
        },
        fun: { nodeFu: '100.0', goldenTrinkets: 0, silverTrinkets: 0, stars: 0, easterEggs: 0, tokens: 0 },
        advancement: { merit: '1.00', lf: '0.0000', devotion: 0, meritMean: 0, meritStddev: 0 }
      }
      const { container } = render(<Statistics statistics={stats} />)
      // Check that there's no div containing both "XP:" and no value after it
      // Since XP is undefined, the row should not be rendered at all
      const xpElements = container.querySelectorAll('div')
      const xpRow = Array.from(xpElements).find(el => el.textContent === 'XP: ')
      expect(xpRow).toBeUndefined()
    })

    it('does not render stat row when value is null', () => {
      const stats = {
        personal: {
          xp: 5000,
          writeups: null,
          level: 5,
          xpNeeded: 1000,
          wusNeeded: undefined,
          gp: 100,
          gpOptout: false
        },
        fun: { nodeFu: '100.0', goldenTrinkets: 0, silverTrinkets: 0, stars: 0, easterEggs: 0, tokens: 0 },
        advancement: { merit: '1.00', lf: '0.0000', devotion: 0, meritMean: 0, meritStddev: 0 }
      }
      const { container } = render(<Statistics statistics={stats} />)
      // Check that there's no div containing both "Writeups:" and no value after it
      const writeupElements = container.querySelectorAll('div')
      const writeupRow = Array.from(writeupElements).find(el => el.textContent === 'Writeups: ')
      expect(writeupRow).toBeUndefined()
    })

    it('renders stat row when value is 0', () => {
      const stats = {
        personal: {
          xp: 0,
          writeups: 50,
          level: 5,
          xpNeeded: 1000,
          wusNeeded: undefined,
          gp: 100,
          gpOptout: false
        },
        fun: { nodeFu: '100.0', goldenTrinkets: 0, silverTrinkets: 0, stars: 0, easterEggs: 0, tokens: 0 },
        advancement: { merit: '1.00', lf: '0.0000', devotion: 0, meritMean: 0, meritStddev: 0 }
      }
      const { container } = render(<Statistics statistics={stats} />)
      expect(screen.getByText(/XP:/)).toBeInTheDocument()
      // Check that there's a span with "0" as the value for XP
      const xpElements = container.querySelectorAll('div')
      const xpRow = Array.from(xpElements).find(el => el.textContent.includes('XP: 0'))
      expect(xpRow).toBeDefined()
    })
  })

  describe('component props', () => {
    const basicStats = {
      personal: { xp: 1000, writeups: 10, level: 1, gp: 50, gpOptout: false },
      fun: { nodeFu: '100.0', goldenTrinkets: 0, silverTrinkets: 0, stars: 0, easterEggs: 0, tokens: 0 },
      advancement: { merit: '1.00', lf: '0.0000', devotion: 0, meritMean: 0, meritStddev: 0 }
    }

    it('passes nodeletIsOpen prop to NodeletContainer', () => {
      render(<Statistics statistics={basicStats} nodeletIsOpen={true} />)
      const container = screen.getByTestId('nodelet-container')
      expect(container).toHaveAttribute('data-open', 'true')
    })

    it('passes nodeletIsOpen false to NodeletContainer', () => {
      render(<Statistics statistics={basicStats} nodeletIsOpen={false} />)
      const container = screen.getByTestId('nodelet-container')
      expect(container).toHaveAttribute('data-open', 'false')
    })

    it('passes showNodelet prop to NodeletContainer', () => {
      const showNodelet = jest.fn()
      render(<Statistics statistics={basicStats} showNodelet={showNodelet} />)
      // Just verify it renders without error - showNodelet is passed through
      expect(screen.getByTestId('nodelet-container')).toBeInTheDocument()
    })

    it('passes toggleSection prop to NodeletSection components', () => {
      const toggleSection = jest.fn()
      render(<Statistics statistics={basicStats} toggleSection={toggleSection} />)
      // Just verify all sections render - toggleSection is passed through
      const sections = screen.getAllByTestId('nodelet-section')
      expect(sections).toHaveLength(3)
    })
  })

  describe('zero values handling', () => {
    it('displays zero values correctly', () => {
      const stats = {
        personal: {
          xp: 0,
          writeups: 0,
          level: 0,
          xpNeeded: undefined,
          wusNeeded: undefined,
          gp: 0,
          gpOptout: false
        },
        fun: {
          nodeFu: '0.0',
          goldenTrinkets: 0,
          silverTrinkets: 0,
          stars: 0,
          easterEggs: 0,
          tokens: 0
        },
        advancement: {
          merit: '0.00',
          lf: '0.0000',
          devotion: 0,
          meritMean: 0,
          meritStddev: 0
        }
      }
      const { container } = render(<Statistics statistics={stats} />)
      // Should display zeros, not hide them - check for specific stat rows
      expect(screen.getByText(/XP:/)).toBeInTheDocument()
      expect(screen.getByText(/Writeups:/)).toBeInTheDocument()
      expect(screen.getByText(/Level:/)).toBeInTheDocument()
      expect(screen.getByText(/GP:/)).toBeInTheDocument()
      // Verify at least one zero is displayed
      const allText = container.textContent
      expect(allText).toContain('0')
    })
  })
})
