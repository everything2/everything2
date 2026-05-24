import React, { useState, useEffect, useRef } from 'react'
import { FaCalendarAlt, FaClock, FaTimes } from 'react-icons/fa'
import { useClickOutside } from '../hooks/useClickOutside'

/**
 * DateTimePicker - Date and time picker component with calendar popup
 * Styles in CSS: .date-time-picker__*
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
  useClickOutside(containerRef, () => setIsOpen(false))

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
    <div ref={containerRef} className="date-time-picker">
      <div className="date-time-picker__wrapper">
        <FaCalendarAlt className="date-time-picker__icon" />
        <input
          type="text"
          value={displayValue}
          onChange={handleInputChange}
          onClick={() => !disabled && setIsOpen(true)}
          disabled={disabled}
          placeholder={placeholder}
          className="date-time-picker__input"
        />
        {clearable && displayValue && !disabled && (
          <button
            type="button"
            onClick={handleClear}
            className="date-time-picker__clear-button"
            title="Clear"
          >
            <FaTimes />
          </button>
        )}
      </div>

      {isOpen && !disabled && (
        <div className="date-time-picker__dropdown">
          {/* Month navigation */}
          <div className="date-time-picker__header">
            <button type="button" onClick={prevMonth} className="date-time-picker__nav-button">&lt;</button>
            <span className="date-time-picker__month-year">
              {monthNames[viewDate.getMonth()]} {viewDate.getFullYear()}
            </span>
            <button type="button" onClick={nextMonth} className="date-time-picker__nav-button">&gt;</button>
          </div>

          {/* Day names */}
          <div className="date-time-picker__day-names">
            {dayNames.map(d => (
              <div key={d} className="date-time-picker__day-name">{d}</div>
            ))}
          </div>

          {/* Calendar grid */}
          <div className="date-time-picker__calendar-grid">
            {calendarDays.map((day, idx) => {
              const isSelected = selectedDate &&
                day === selectedDate.day &&
                viewDate.getMonth() + 1 === selectedDate.month &&
                viewDate.getFullYear() === selectedDate.year
              const isToday = day &&
                new Date().getDate() === day &&
                new Date().getMonth() === viewDate.getMonth() &&
                new Date().getFullYear() === viewDate.getFullYear()

              const cellClasses = [
                'date-time-picker__day-cell',
                day ? 'date-time-picker__day-cell--active' : '',
                isSelected ? 'date-time-picker__day-cell--selected' : '',
                isToday && !isSelected ? 'date-time-picker__day-cell--today' : ''
              ].filter(Boolean).join(' ')

              return (
                <div
                  key={idx}
                  onClick={() => handleDayClick(day)}
                  className={cellClasses}
                >
                  {day}
                </div>
              )
            })}
          </div>

          {/* Time picker */}
          {showTime && (
            <div className="date-time-picker__time-section">
              <FaClock className="date-time-picker__time-icon" />
              <input
                type="number"
                min="0"
                max="23"
                value={selectedDate?.hour ?? ''}
                onChange={(e) => handleTimeChange('hour', e.target.value)}
                className="date-time-picker__time-input"
                placeholder="HH"
              />
              <span className="date-time-picker__time-separator">:</span>
              <input
                type="number"
                min="0"
                max="59"
                value={selectedDate?.minute ?? ''}
                onChange={(e) => handleTimeChange('minute', e.target.value)}
                className="date-time-picker__time-input"
                placeholder="MM"
              />
              <span className="date-time-picker__time-separator">:</span>
              <input
                type="number"
                min="0"
                max="59"
                value={selectedDate?.second ?? ''}
                onChange={(e) => handleTimeChange('second', e.target.value)}
                className="date-time-picker__time-input"
                placeholder="SS"
              />
            </div>
          )}

          {/* Quick actions */}
          <div className="date-time-picker__actions">
            <button type="button" onClick={handleSetNow} className="date-time-picker__action-button">
              Now
            </button>
            <button type="button" onClick={() => setIsOpen(false)} className="date-time-picker__action-button">
              Done
            </button>
          </div>
        </div>
      )}
    </div>
  )
}

export default DateTimePicker
