import React, { useState } from 'react'

/**
 * EverythingPollCreator - Create new E2 user polls
 *
 * Features:
 * - Form validation (title, question, minimum options)
 * - Dynamic option management (add/remove)
 * - Automatic "None of the above" option
 * - Modern Kernel Blue UI
 * - Real-time character count
 */
const EverythingPollCreator = ({ data, user }) => {
  const { poll_god = 'mauler', polls_disabled = false, can_create = true } = data || {}

  // Form state
  const [title, setTitle] = useState('')
  const [question, setQuestion] = useState('')
  const [options, setOptions] = useState(['', '', '', '']) // Start with 4 empty options
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState(null)
  const [success, setSuccess] = useState(null)

  // Kernel Blue colors
  const colors = {
    primary: '#38495e',
    secondary: '#507898',
    highlight: '#4060b0',
    accent: '#3bb5c3',
    background: '#f8f9f9',
    text: '#111111',
    error: '#c75050',
    success: '#4caf50'
  }

  const maxOptions = 12
  const titleMaxLength = 64
  const optionMaxLength = 255
  const questionMaxLength = 255

  // Add new option field
  const addOption = () => {
    if (options.length < maxOptions) {
      setOptions([...options, ''])
    }
  }

  // Remove option field
  const removeOption = (index) => {
    if (options.length > 1) {
      setOptions(options.filter((_, i) => i !== index))
    }
  }

  // Update option value
  const updateOption = (index, value) => {
    const newOptions = [...options]
    newOptions[index] = value
    setOptions(newOptions)
  }

  // Validate form
  const validate = () => {
    if (!title.trim()) {
      return 'Poll title is required'
    }
    if (title.length > titleMaxLength) {
      return `Poll title must be ${titleMaxLength} characters or less`
    }
    if (!question.trim()) {
      return 'Poll question is required'
    }
    if (question.length > questionMaxLength) {
      return `Question must be ${questionMaxLength} characters or less`
    }

    const filledOptions = options.filter(opt => opt.trim())
    if (filledOptions.length < 2) {
      return 'At least 2 answer options are required'
    }

    // Check for option length
    for (let opt of filledOptions) {
      if (opt.length > optionMaxLength) {
        return `Each option must be ${optionMaxLength} characters or less`
      }
    }

    return null
  }

  // Handle submit
  const handleSubmit = async (e) => {
    e.preventDefault()

    const validationError = validate()
    if (validationError) {
      setError(validationError)
      return
    }

    setSubmitting(true)
    setError(null)
    setSuccess(null)

    try {
      // Filter out empty options
      const filledOptions = options.filter(opt => opt.trim())

      const response = await fetch('/api/poll_creator/create', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          title: title.trim(),
          question: question.trim(),
          options: filledOptions
        })
      })

      const result = await response.json()

      if (result.success) {
        // Create success message with links
        const pollUrl = `/node/${result.poll_id}`
        const directoryUrl = '/node/Everything%20Poll%20Directory'

        setSuccess(
          <>
            Poll <a href={pollUrl} style={linkStyle}>"{result.poll_title}"</a> created successfully!
            View it in the <a href={directoryUrl} style={linkStyle}>Everything Poll Directory</a>.
          </>
        )

        // Reset form
        setTitle('')
        setQuestion('')
        setOptions(['', '', '', ''])
      } else {
        setError(result.error || 'Failed to create poll')
      }
    } catch (err) {
      setError('Network error: ' + err.message)
    }

    setSubmitting(false)
  }

  // Styles
  const containerStyle = {
    padding: '20px',
    maxWidth: '900px',
    margin: '0 auto'
  }

  const headerStyle = {
    marginBottom: '30px',
    borderBottom: `2px solid ${colors.primary}`,
    paddingBottom: '15px'
  }

  const titleStyle = {
    fontSize: '28px',
    color: colors.primary,
    marginBottom: '15px'
  }

  const infoBoxStyle = {
    backgroundColor: colors.background,
    padding: '20px',
    borderRadius: '8px',
    marginBottom: '30px',
    border: `1px solid ${colors.secondary}40`
  }

  const infoTitleStyle = {
    fontSize: '18px',
    color: colors.primary,
    marginBottom: '15px',
    fontWeight: '600'
  }

  const listStyle = {
    listStyleType: 'disc',
    marginLeft: '25px',
    lineHeight: '1.8',
    color: colors.text
  }

  const listItemStyle = {
    marginBottom: '8px'
  }

  const formStyle = {
    backgroundColor: '#fff',
    padding: '30px',
    borderRadius: '8px',
    boxShadow: '0 1px 3px rgba(0,0,0,0.1)'
  }

  const fieldGroupStyle = {
    marginBottom: '25px'
  }

  const labelStyle = {
    display: 'block',
    marginBottom: '8px',
    fontSize: '14px',
    fontWeight: '600',
    color: colors.primary
  }

  const inputStyle = {
    width: '100%',
    padding: '10px 12px',
    border: `1px solid ${colors.secondary}60`,
    borderRadius: '4px',
    fontSize: '14px',
    backgroundColor: '#fff',
    color: colors.text,
    boxSizing: 'border-box'
  }

  const charCountStyle = (current, max) => ({
    fontSize: '12px',
    color: current > max ? colors.error : colors.secondary,
    marginTop: '4px',
    textAlign: 'right'
  })

  const optionRowStyle = {
    display: 'flex',
    gap: '10px',
    alignItems: 'center',
    marginBottom: '10px'
  }

  const optionNumberStyle = {
    fontSize: '14px',
    fontWeight: '600',
    color: colors.secondary,
    width: '30px',
    flexShrink: 0
  }

  const removeButtonStyle = {
    padding: '8px 12px',
    backgroundColor: '#fff',
    color: colors.error,
    border: `1px solid ${colors.error}`,
    borderRadius: '4px',
    cursor: 'pointer',
    fontSize: '12px',
    flexShrink: 0
  }

  const addButtonStyle = {
    padding: '8px 16px',
    backgroundColor: colors.accent,
    color: '#fff',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
    fontSize: '14px',
    marginTop: '10px'
  }

  const submitButtonStyle = {
    padding: '12px 30px',
    backgroundColor: submitting ? '#999' : colors.highlight,
    color: '#fff',
    border: 'none',
    borderRadius: '4px',
    cursor: submitting ? 'wait' : 'pointer',
    fontSize: '16px',
    fontWeight: '600',
    marginTop: '20px'
  }

  const alertStyle = (type) => ({
    padding: '15px',
    borderRadius: '4px',
    marginBottom: '20px',
    backgroundColor: type === 'error' ? '#fff5f5' : '#f0fdf4',
    border: `1px solid ${type === 'error' ? '#feb2b2' : '#86efac'}`,
    color: type === 'error' ? colors.error : colors.success
  })

  const linkStyle = {
    color: colors.highlight,
    textDecoration: 'none'
  }

  const noneOptionStyle = {
    padding: '10px 12px',
    backgroundColor: colors.background,
    border: `1px solid ${colors.secondary}40`,
    borderRadius: '4px',
    fontSize: '14px',
    color: colors.secondary,
    fontStyle: 'italic',
    marginTop: '10px'
  }

  if (polls_disabled) {
    return (
      <div style={containerStyle}>
        <div style={headerStyle}>
          <h1 style={titleStyle}>E2 Poll Creator</h1>
        </div>
        <div style={alertStyle('error')}>
          Sorry, poll creation has been temporarily disabled.
        </div>
      </div>
    )
  }

  if (!can_create) {
    return (
      <div style={containerStyle}>
        <div style={headerStyle}>
          <h1 style={titleStyle}>E2 Poll Creator</h1>
        </div>
        <div style={alertStyle('error')}>
          You must be logged in to create polls.
        </div>
      </div>
    )
  }

  return (
    <div style={containerStyle}>
      {/* Header */}
      <div style={headerStyle}>
        <h1 style={titleStyle}>E2 Poll Creator</h1>
      </div>

      {/* Important Information */}
      <div style={infoBoxStyle}>
        <h2 style={infoTitleStyle}>Important! Read this or weep!</h2>
        <ul style={listStyle}>
          <li style={listItemStyle}>
            Welcome to the E2 Poll Creator! Please use this form to create a poll on any topic
            that interests you. Please do not abuse this privilege.
          </li>
          <li style={listItemStyle}>
            By default, all polls have a "None of the above" option at the end. Be imaginative
            and use as many of the available option slots as possible so that it will not be needed.
          </li>
          <li style={listItemStyle}>
            People cannot vote on a poll until the current poll god,{' '}
            <a href={`/user/${poll_god}`} style={linkStyle}>{poll_god}</a>, has made it the{' '}
            <a href="/node/Everything%20User%20Poll" style={linkStyle}>Current User Poll</a>.
          </li>
          <li style={listItemStyle}>
            Old completed polls are at the{' '}
            <a href="/node/Everything%20Poll%20Archive" style={linkStyle}>Everything Poll Archive</a>.
            New polls in the queue for posting are at{' '}
            <a href="/node/Everything%20Poll%20Directory" style={linkStyle}>Everything Poll Directory</a>.
            For more information, see <a href="/node/Polls" style={linkStyle}>Polls</a>.
          </li>
          <li style={listItemStyle}>
            If you accidentally submit a poll before it is complete, /msg{' '}
            <a href={`/user/${poll_god}`} style={linkStyle}>{poll_god}</a>, who will delete it.
          </li>
          <li style={listItemStyle}>
            You cannot create a poll without a question, without a title, or with the same title as
            an existing poll.
          </li>
        </ul>
      </div>

      {/* Poll Creation Form */}
      <form onSubmit={handleSubmit} style={formStyle}>
        <h2 style={{ ...infoTitleStyle, marginTop: 0 }}>Submit a new poll</h2>

        {/* Title */}
        <div style={fieldGroupStyle}>
          <label style={labelStyle}>Poll Title: *</label>
          <input
            type="text"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            maxLength={titleMaxLength + 10}
            placeholder="Enter a unique, descriptive title..."
            style={inputStyle}
          />
          <div style={charCountStyle(title.length, titleMaxLength)}>
            {title.length} / {titleMaxLength} characters
          </div>
        </div>

        {/* Question */}
        <div style={fieldGroupStyle}>
          <label style={labelStyle}>Question: *</label>
          <input
            type="text"
            value={question}
            onChange={(e) => setQuestion(e.target.value)}
            maxLength={questionMaxLength + 10}
            placeholder="What question do you want to ask?"
            style={inputStyle}
          />
          <div style={charCountStyle(question.length, questionMaxLength)}>
            {question.length} / {questionMaxLength} characters
          </div>
        </div>

        {/* Options */}
        <div style={fieldGroupStyle}>
          <label style={labelStyle}>Answer Options: (minimum 2 required)</label>
          {options.map((option, idx) => (
            <div key={idx} style={optionRowStyle}>
              <span style={optionNumberStyle}>{idx + 1}.</span>
              <input
                type="text"
                value={option}
                onChange={(e) => updateOption(idx, e.target.value)}
                maxLength={optionMaxLength + 10}
                placeholder={`Option ${idx + 1}...`}
                style={{ ...inputStyle, flex: 1 }}
              />
              {options.length > 1 && (
                <button
                  type="button"
                  onClick={() => removeOption(idx)}
                  style={removeButtonStyle}
                  title="Remove this option"
                >
                  Remove
                </button>
              )}
            </div>
          ))}

          {options.length < maxOptions && (
            <button
              type="button"
              onClick={addOption}
              style={addButtonStyle}
            >
              + Add Another Option ({options.length}/{maxOptions})
            </button>
          )}

          {/* "None of the above" indicator */}
          <div style={noneOptionStyle}>
            And finally: None of the above (automatically added)
          </div>
        </div>

        {/* Submit Button */}
        <button
          type="submit"
          disabled={submitting}
          style={submitButtonStyle}
        >
          {submitting ? 'Creating Poll...' : 'Create Poll'}
        </button>

        {/* Success/Error Messages - shown directly under the submit button */}
        {error && <div style={alertStyle('error')}>{error}</div>}
        {success && <div style={alertStyle('success')}>{success}</div>}
      </form>
    </div>
  )
}

export default EverythingPollCreator
