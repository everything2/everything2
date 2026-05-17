import React, { useState } from 'react'

/**
 * EverythingPollCreator - Create new E2 user polls
 * Styles in CSS: .poll-creator__*
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
            Poll <a href={pollUrl} className="poll-creator__link">"{result.poll_title}"</a> created successfully!
            View it in the <a href={directoryUrl} className="poll-creator__link">Everything Poll Directory</a>.
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

  // Helper for character count class
  const getCharCountClass = (current, max) => {
    return current > max
      ? 'poll-creator__char-count poll-creator__char-count--over'
      : 'poll-creator__char-count'
  }

  if (polls_disabled) {
    return (
      <div className="poll-creator">
        <div className="poll-creator__header">
          <h1 className="poll-creator__title">E2 Poll Creator</h1>
        </div>
        <div className="poll-creator__alert poll-creator__alert--error">
          Sorry, poll creation has been temporarily disabled.
        </div>
      </div>
    )
  }

  if (!can_create) {
    return (
      <div className="poll-creator">
        <div className="poll-creator__header">
          <h1 className="poll-creator__title">E2 Poll Creator</h1>
        </div>
        <div className="poll-creator__alert poll-creator__alert--error">
          You must be logged in to create polls.
        </div>
      </div>
    )
  }

  return (
    <div className="poll-creator">
      {/* Header */}
      <div className="poll-creator__header">
        <h1 className="poll-creator__title">E2 Poll Creator</h1>
      </div>

      {/* Important Information */}
      <div className="poll-creator__info-box">
        <h2 className="poll-creator__info-title">Important! Read this or weep!</h2>
        <ul className="poll-creator__list">
          <li className="poll-creator__list-item">
            Welcome to the E2 Poll Creator! Please use this form to create a poll on any topic
            that interests you. Please do not abuse this privilege.
          </li>
          <li className="poll-creator__list-item">
            By default, all polls have a "None of the above" option at the end. Be imaginative
            and use as many of the available option slots as possible so that it will not be needed.
          </li>
          <li className="poll-creator__list-item">
            People cannot vote on a poll until the current poll god,{' '}
            <a href={`/user/${poll_god}`} className="poll-creator__link">{poll_god}</a>, has made it the{' '}
            <a href="/node/Everything%20User%20Poll" className="poll-creator__link">Current User Poll</a>.
          </li>
          <li className="poll-creator__list-item">
            Old completed polls are at the{' '}
            <a href="/node/Everything%20Poll%20Archive" className="poll-creator__link">Everything Poll Archive</a>.
            New polls in the queue for posting are at{' '}
            <a href="/node/Everything%20Poll%20Directory" className="poll-creator__link">Everything Poll Directory</a>.
            For more information, see <a href="/node/Polls" className="poll-creator__link">Polls</a>.
          </li>
          <li className="poll-creator__list-item">
            If you accidentally submit a poll before it is complete, /msg{' '}
            <a href={`/user/${poll_god}`} className="poll-creator__link">{poll_god}</a>, who will delete it.
          </li>
          <li className="poll-creator__list-item">
            You cannot create a poll without a question, without a title, or with the same title as
            an existing poll.
          </li>
        </ul>
      </div>

      {/* Poll Creation Form */}
      <form onSubmit={handleSubmit} className="poll-creator__form">
        <h2 className="poll-creator__info-title">Submit a new poll</h2>

        {/* Title */}
        <div className="poll-creator__field-group">
          <label className="poll-creator__label">Poll Title: *</label>
          <input
            type="text"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            maxLength={titleMaxLength + 10}
            placeholder="Enter a unique, descriptive title..."
            className="poll-creator__input"
          />
          <div className={getCharCountClass(title.length, titleMaxLength)}>
            {title.length} / {titleMaxLength} characters
          </div>
        </div>

        {/* Question */}
        <div className="poll-creator__field-group">
          <label className="poll-creator__label">Question: *</label>
          <input
            type="text"
            value={question}
            onChange={(e) => setQuestion(e.target.value)}
            maxLength={questionMaxLength + 10}
            placeholder="What question do you want to ask?"
            className="poll-creator__input"
          />
          <div className={getCharCountClass(question.length, questionMaxLength)}>
            {question.length} / {questionMaxLength} characters
          </div>
        </div>

        {/* Options */}
        <div className="poll-creator__field-group">
          <label className="poll-creator__label">Answer Options: (minimum 2 required)</label>
          {options.map((option, idx) => (
            <div key={idx} className="poll-creator__option-row">
              <span className="poll-creator__option-number">{idx + 1}.</span>
              <input
                type="text"
                value={option}
                onChange={(e) => updateOption(idx, e.target.value)}
                maxLength={optionMaxLength + 10}
                placeholder={`Option ${idx + 1}...`}
                className="poll-creator__input"
                style={{ flex: 1 }}
              />
              {options.length > 1 && (
                <button
                  type="button"
                  onClick={() => removeOption(idx)}
                  className="poll-creator__remove-btn"
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
              className="poll-creator__add-btn"
            >
              + Add Another Option ({options.length}/{maxOptions})
            </button>
          )}

          {/* "None of the above" indicator */}
          <div className="poll-creator__none-option">
            And finally: None of the above (automatically added)
          </div>
        </div>

        {/* Submit Button */}
        <button
          type="submit"
          disabled={submitting}
          className="poll-creator__submit-btn"
        >
          {submitting ? 'Creating Poll...' : 'Create Poll'}
        </button>

        {/* Success/Error Messages - shown directly under the submit button */}
        {error && <div className="poll-creator__alert poll-creator__alert--error">{error}</div>}
        {success && <div className="poll-creator__alert poll-creator__alert--success">{success}</div>}
      </form>
    </div>
  )
}

export default EverythingPollCreator
