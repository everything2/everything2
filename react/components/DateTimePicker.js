import React, { useState, useEffect, useRef } from 'react'
import { FaCalendarAlt, FaClock, FaTimes } from 'react-icons/fa'

/**
 * DateTimePicker - Date and time picker component with calendar popup
 *
 * Props:
 * - value: string in format "YYYY-MM-DD HH:MM:SS" or ISO format
 * - onChange: callback with new value in "YYYY-MM-DD HH:MM:SS" format
 * - disabled: boolean to disable input
 * - placeholder: placeholder text
 * - showTime: boolean to show time picker (default: true)
 * - clearable: boolean to show clear button (default: true)
 */
const DateTimePicker = ({
  value,
  onChange,
  disabled = false,
  placeholder = 'Select date/time...',
  showTime = true,
  clearable = true
}) => {
  const [isOpen, setIsOpen] = useState(false)
  const [viewDate, setViewDate] = useState(() => {
    if (value) {
      const parsed = parseDateTime(value)
      return parsed ? new Date(parsed.year, parsed.month - 1, 1) : new Date()
    }
    return new Date()
  })
  const [selectedDate, setSelectedDate] = useState(() => parseDateTime(value))
  const containerRef = useRef(null)

  // Parse "YYYY-MM-DD HH:MM:SS" or ISO format into components
  function parseDateTime(str) {
    if (!str) return null
    // Handle both "YYYY-MM-DD HH:MM:SS" and ISO formats
    const match = str.match(/^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2}))?)?/)
    if (!match) return null

    const year = parseInt(match[1], 10)
    const month = parseInt(match[2], 10)
    const day = parseInt(match[3], 10)

    // Treat zero dates (0000-00-00 or similar) as null/empty
    // These come from MySQL default values and should show current date instead
    if (year === 0 || month === 0 || day === 0) {
      return null
    }

    return {
      year,
      month,
      day,
      hour: match[4] ? parseInt(match[4], 10) : 0,
      minute: match[5] ? parseInt(match[5], 10) : 0,
      second: match[6] ? parseInt(match[6], 10) : 0
    }
  }

  // Format components back to "YYYY-MM-DD HH:MM:SS"
  function formatDateTime(dt) {
    if (!dt) return ''
    const pad = (n) => n.toString().padStart(2, '0')
    if (showTime) {
      return `${dt.year}-${pad(dt.month)}-${pad(dt.day)} ${pad(dt.hour)}:${pad(dt.minute)}:${pad(dt.second)}`
    }
    return `${dt.year}-${pad(dt.month)}-${pad(dt.day)}`
  }

  // Update internal state when value prop changes
  useEffect(() => {
    const parsed = parseDateTime(value)
    setSelectedDate(parsed)
    if (parsed) {
      setViewDate(new Date(parsed.year, parsed.month - 1, 1))
    }
  }, [value])

  // Close dropdown when clicking outside
  useEffect(() => {
    const handleClickOutside = (e) => {
      if (containerRef.current && !containerRef.current.contains(e.target)) {
        setIsOpen(false)
      }
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [])

  // Get days in month
  const getDaysInMonth = (year, month) => {
    return new Date(year, month, 0).getDate()
  }

  // Get day of week for first day of month (0=Sun, 6=Sat)
  const getFirstDayOfMonth = (year, month) => {
    return new Date(year, month - 1, 1).getDay()
  }

  // Generate calendar grid
  const generateCalendarDays = () => {
    const year = viewDate.getFullYear()
    const month = viewDate.getMonth() + 1
    const daysInMonth = getDaysInMonth(year, month)
    const firstDay = getFirstDayOfMonth(year, month)

    const days = []
    // Empty cells for days before first of month
    for (let i = 0; i < firstDay; i++) {
      days.push(null)
    }
    // Actual days
    for (let d = 1; d <= daysInMonth; d++) {
      days.push(d)
    }
    return days
  }

  // Handle day selection
  const handleDayClick = (day) => {
    if (!day) return
    const newDate = {
      year: viewDate.getFullYear(),
      month: viewDate.getMonth() + 1,
      day,
      hour: selectedDate?.hour || 12,
      minute: selectedDate?.minute || 0,
      second: selectedDate?.second || 0
    }
    setSelectedDate(newDate)
    onChange(formatDateTime(newDate))
    if (!showTime) {
      setIsOpen(false)
    }
  }

  // Handle time change
  const handleTimeChange = (field, value) => {
    if (!selectedDate) return
    const newDate = { ...selectedDate, [field]: parseInt(value, 10) || 0 }
    setSelectedDate(newDate)
    onChange(formatDateTime(newDate))
  }

  // Navigate months
  const prevMonth = () => {
    setViewDate(new Date(viewDate.getFullYear(), viewDate.getMonth() - 1, 1))
  }

  const nextMonth = () => {
    setViewDate(new Date(viewDate.getFullYear(), viewDate.getMonth() + 1, 1))
  }

  // Handle direct text input
  const handleInputChange = (e) => {
    onChange(e.target.value)
  }

  // Clear value
  const handleClear = (e) => {
    e.stopPropagation()
    setSelectedDate(null)
    onChange('')
    setIsOpen(false)
  }

  // Set to now
  const handleSetNow = () => {
    const now = new Date()
    const newDate = {
      year: now.getFullYear(),
      month: now.getMonth() + 1,
      day: now.getDate(),
      hour: now.getHours(),
      minute: now.getMinutes(),
      second: now.getSeconds()
    }
    setSelectedDate(newDate)
    setViewDate(new Date(now.getFullYear(), now.getMonth(), 1))
    onChange(formatDateTime(newDate))
  }

  const monthNames = ['January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December']
  const dayNames = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa']

  const calendarDays = generateCalendarDays()
  const displayValue = value || ''

  return (
    <div ref={containerRef} style={styles.container}>
      <div style={styles.inputWrapper}>
        <FaCalendarAlt style={styles.icon} />
        <input
          type="text"
          value={displayValue}
          onChange={handleInputChange}
          onClick={() => !disabled && setIsOpen(true)}
          disabled={disabled}
          placeholder={placeholder}
          style={styles.input}
        />
        {clearable && displayValue && !disabled && (
          <button
            type="button"
            onClick={handleClear}
            style={styles.clearButton}
            title="Clear"
          >
            <FaTimes />
          </button>
        )}
      </div>

      {isOpen && !disabled && (
        <div style={styles.dropdown}>
          {/* Month navigation */}
          <div style={styles.header}>
            <button type="button" onClick={prevMonth} style={styles.navButton}>&lt;</button>
            <span style={styles.monthYear}>
              {monthNames[viewDate.getMonth()]} {viewDate.getFullYear()}
            </span>
            <button type="button" onClick={nextMonth} style={styles.navButton}>&gt;</button>
          </div>

          {/* Day names */}
          <div style={styles.dayNames}>
            {dayNames.map(d => (
              <div key={d} style={styles.dayName}>{d}</div>
            ))}
          </div>

          {/* Calendar grid */}
          <div style={styles.calendarGrid}>
            {calendarDays.map((day, idx) => {
              const isSelected = selectedDate &&
                day === selectedDate.day &&
                viewDate.getMonth() + 1 === selectedDate.month &&
                viewDate.getFullYear() === selectedDate.year
              const isToday = day &&
                new Date().getDate() === day &&
                new Date().getMonth() === viewDate.getMonth() &&
                new Date().getFullYear() === viewDate.getFullYear()

              return (
                <div
                  key={idx}
                  onClick={() => handleDayClick(day)}
                  style={{
                    ...styles.dayCell,
                    ...(day ? styles.dayCellActive : {}),
                    ...(isSelected ? styles.dayCellSelected : {}),
                    ...(isToday && !isSelected ? styles.dayCellToday : {})
                  }}
                >
                  {day}
                </div>
              )
            })}
          </div>

          {/* Time picker */}
          {showTime && (
            <div style={styles.timeSection}>
              <FaClock style={styles.timeIcon} />
              <input
                type="number"
                min="0"
                max="23"
                value={selectedDate?.hour ?? ''}
                onChange={(e) => handleTimeChange('hour', e.target.value)}
                style={styles.timeInput}
                placeholder="HH"
              />
              <span style={styles.timeSeparator}>:</span>
              <input
                type="number"
                min="0"
                max="59"
                value={selectedDate?.minute ?? ''}
                onChange={(e) => handleTimeChange('minute', e.target.value)}
                style={styles.timeInput}
                placeholder="MM"
              />
              <span style={styles.timeSeparator}>:</span>
              <input
                type="number"
                min="0"
                max="59"
                value={selectedDate?.second ?? ''}
                onChange={(e) => handleTimeChange('second', e.target.value)}
                style={styles.timeInput}
                placeholder="SS"
              />
            </div>
          )}

          {/* Quick actions */}
          <div style={styles.actions}>
            <button type="button" onClick={handleSetNow} style={styles.actionButton}>
              Now
            </button>
            <button type="button" onClick={() => setIsOpen(false)} style={styles.actionButton}>
              Done
            </button>
          </div>
        </div>
      )}
    </div>
  )
}

const styles = {
  container: {
    position: 'relative'
  },
  inputWrapper: {
    position: 'relative',
    display: 'flex',
    alignItems: 'center'
  },
  icon: {
    position: 'absolute',
    left: 10,
    color: '#507898',
    fontSize: 14,
    pointerEvents: 'none'
  },
  input: {
    width: '100%',
    padding: '8px 32px 8px 32px',
    fontSize: 14,
    border: '1px solid #507898',
    borderRadius: 4,
    boxSizing: 'border-box'
  },
  clearButton: {
    position: 'absolute',
    right: 8,
    background: 'none',
    border: 'none',
    color: '#999',
    cursor: 'pointer',
    padding: 4,
    fontSize: 12,
    display: 'flex',
    alignItems: 'center'
  },
  dropdown: {
    position: 'absolute',
    top: '100%',
    left: 0,
    backgroundColor: '#fff',
    border: '1px solid #507898',
    borderRadius: 4,
    boxShadow: '0 4px 12px rgba(0,0,0,0.15)',
    zIndex: 1000,
    padding: 12,
    marginTop: 4,
    minWidth: 280
  },
  header: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12
  },
  navButton: {
    background: 'none',
    border: '1px solid #ddd',
    borderRadius: 4,
    padding: '4px 10px',
    cursor: 'pointer',
    fontSize: 14,
    color: '#38495e'
  },
  monthYear: {
    fontWeight: 'bold',
    color: '#38495e',
    fontSize: 14
  },
  dayNames: {
    display: 'grid',
    gridTemplateColumns: 'repeat(7, 1fr)',
    gap: 2,
    marginBottom: 4
  },
  dayName: {
    textAlign: 'center',
    fontSize: 12,
    fontWeight: 'bold',
    color: '#507898',
    padding: 4
  },
  calendarGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(7, 1fr)',
    gap: 2
  },
  dayCell: {
    textAlign: 'center',
    padding: 8,
    fontSize: 14,
    borderRadius: 4,
    minHeight: 32,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center'
  },
  dayCellActive: {
    cursor: 'pointer',
    color: '#38495e'
  },
  dayCellSelected: {
    backgroundColor: '#4060b0',
    color: '#fff',
    fontWeight: 'bold'
  },
  dayCellToday: {
    backgroundColor: '#e8f4f8',
    fontWeight: 'bold'
  },
  timeSection: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 4,
    marginTop: 12,
    paddingTop: 12,
    borderTop: '1px solid #eee'
  },
  timeIcon: {
    color: '#507898',
    marginRight: 8,
    fontSize: 14
  },
  timeInput: {
    width: 45,
    padding: '6px 4px',
    fontSize: 14,
    border: '1px solid #ddd',
    borderRadius: 4,
    textAlign: 'center'
  },
  timeSeparator: {
    fontWeight: 'bold',
    color: '#38495e'
  },
  actions: {
    display: 'flex',
    justifyContent: 'flex-end',
    gap: 8,
    marginTop: 12,
    paddingTop: 8,
    borderTop: '1px solid #eee'
  },
  actionButton: {
    padding: '6px 12px',
    fontSize: 12,
    backgroundColor: '#507898',
    color: '#fff',
    border: 'none',
    borderRadius: 4,
    cursor: 'pointer'
  }
}

export default DateTimePicker
