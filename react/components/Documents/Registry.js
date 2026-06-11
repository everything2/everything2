import React, { useState, useEffect } from 'react'
import LinkNode from '../LinkNode'
import { FaClipboardList, FaTimes, FaPlus, FaCheck, FaTrash, FaUser } from 'react-icons/fa'
import { renderE2Content } from '../Editor/E2HtmlSanitizer'

/**
 * Registry - Display and manage registry entries
 * Styles in CSS: .registry__*
 *
 * Registries allow users to submit data entries (text, dates, yes/no).
 * Only logged-in users can view and submit entries.
 * Admins can delete any user's entry.
 *
 * input_style options:
 * - 'text' or null: free text input
 * - 'date': date picker with optional secret year
 * - 'yes/no': yes/no dropdown
 */
const Registry = ({ data }) => {
  const { registry, entries: initialEntries, user_entry: initialUserEntry, is_guest, is_admin } = data

  const [entries, setEntries] = useState(initialEntries || [])
  const [userEntry, setUserEntry] = useState(initialUserEntry)
  const [formData, setFormData] = useState({
    data: initialUserEntry?.data || '',
    comments: initialUserEntry?.comments || '',
    in_user_profile: initialUserEntry?.in_user_profile || false,
    // Date fields for 'date' input_style
    year: 'secret',
    month: 1,
    day: 1
  })
  const [message, setMessage] = useState(null)
  const [isSubmitting, setIsSubmitting] = useState(false)

  // Parse existing date entry if input_style is 'date'
  useEffect(() => {
    if (registry.input_style === 'date' && initialUserEntry?.data) {
      const parts = initialUserEntry.data.split('-')
      if (parts.length === 3) {
        // YYYY-MM-DD
        setFormData(prev => ({
          ...prev,
          year: parts[0],
          month: parseInt(parts[1], 10),
          day: parseInt(parts[2], 10)
        }))
      } else if (parts.length === 2) {
        // MM-DD (secret year)
        setFormData(prev => ({
          ...prev,
          year: 'secret',
          month: parseInt(parts[0], 10),
          day: parseInt(parts[1], 10)
        }))
      }
    }
  }, [registry.input_style, initialUserEntry])

  // Guest view
  if (is_guest) {
    return (
      <div className="registry">
        <div className="registry__header">
          <FaClipboardList className="registry__header-icon" />
          <span className="registry__title">{registry.title}</span>
        </div>

        <div className="registry__guest-message">
          <p className="registry__guest-center">
            <LinkNode nodeId={null} title="Registry Information" />
          </p>
          <p>Registries are only available to logged in users at this time.</p>
        </div>
      </div>
    )
  }

  // Build date data string
  const buildDateString = () => {
    const month = String(formData.month).padStart(2, '0')
    const day = String(formData.day).padStart(2, '0')
    if (formData.year === 'secret') {
      return `${month}-${day}`
    }
    return `${formData.year}-${month}-${day}`
  }

  // Handle form submission
  const handleSubmit = async (e) => {
    e.preventDefault()
    setIsSubmitting(true)
    setMessage(null)

    let submitData = formData.data
    if (registry.input_style === 'date') {
      submitData = buildDateString()
    }

    try {
      const response = await fetch(`/api/registrations/${registry.node_id}/action/submit`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          data: submitData,
          comments: formData.comments,
          in_user_profile: formData.in_user_profile
        })
      })
      const result = await response.json()

      if (result.success) {
        setEntries(result.entries)
        setUserEntry(result.user_entry)
        setMessage({ type: 'success', text: result.message })
      } else {
        setMessage({ type: 'error', text: result.error })
      }
    } catch (error) {
      setMessage({ type: 'error', text: 'Failed to submit entry' })
    } finally {
      setIsSubmitting(false)
    }
  }

  // Handle user deleting their own entry
  const handleDeleteOwn = async () => {
    if (!window.confirm('Are you sure you want to remove your entry?')) return

    setIsSubmitting(true)
    setMessage(null)

    try {
      const response = await fetch(`/api/registrations/${registry.node_id}/action/delete`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' }
      })
      const result = await response.json()

      if (result.success) {
        setEntries(result.entries)
        setUserEntry(null)
        setFormData({ data: '', comments: '', in_user_profile: false, year: 'secret', month: 1, day: 1 })
        setMessage({ type: 'success', text: result.message })
      } else {
        setMessage({ type: 'error', text: result.error })
      }
    } catch (error) {
      setMessage({ type: 'error', text: 'Failed to remove entry' })
    } finally {
      setIsSubmitting(false)
    }
  }

  // Handle admin deleting any entry
  const handleAdminDelete = async (userId, username) => {
    if (!window.confirm(`Are you sure you want to delete the entry for ${username}?`)) return

    setIsSubmitting(true)
    setMessage(null)

    try {
      const response = await fetch(`/api/registrations/${registry.node_id}/action/admin_delete`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ user_id: userId })
      })
      const result = await response.json()

      if (result.success) {
        setEntries(result.entries)
        setMessage({ type: 'success', text: result.message })
      } else {
        setMessage({ type: 'error', text: result.error })
      }
    } catch (error) {
      setMessage({ type: 'error', text: 'Failed to delete entry' })
    } finally {
      setIsSubmitting(false)
    }
  }

  // Render input based on input_style
  const renderInput = () => {
    const inputStyle = registry.input_style || 'text'

    if (inputStyle === 'date') {
      const currentYear = new Date().getFullYear()
      const years = ['secret', ...Array.from({ length: currentYear - 1899 }, (_, i) => 1900 + i)]
      const months = Array.from({ length: 12 }, (_, i) => i + 1)
      const days = Array.from({ length: 31 }, (_, i) => i + 1)

      return (
        <div className="registry__date-row">
          <select
            value={formData.year}
            onChange={(e) => setFormData({ ...formData, year: e.target.value })}
            className="registry__select"
          >
            {years.map(y => (
              <option key={y} value={y}>{y === 'secret' ? 'Year (secret)' : y}</option>
            ))}
          </select>
          <select
            value={formData.month}
            onChange={(e) => setFormData({ ...formData, month: parseInt(e.target.value, 10) })}
            className="registry__select"
          >
            {months.map(m => (
              <option key={m} value={m}>{String(m).padStart(2, '0')}</option>
            ))}
          </select>
          <select
            value={formData.day}
            onChange={(e) => setFormData({ ...formData, day: parseInt(e.target.value, 10) })}
            className="registry__select"
          >
            {days.map(d => (
              <option key={d} value={d}>{String(d).padStart(2, '0')}</option>
            ))}
          </select>
        </div>
      )
    }

    if (inputStyle === 'yes/no') {
      return (
        <select
          value={formData.data}
          onChange={(e) => setFormData({ ...formData, data: e.target.value })}
          className="registry__select"
        >
          <option value="">Choose...</option>
          <option value="Yes">Yes</option>
          <option value="No">No</option>
        </select>
      )
    }

    // Default text input
    return (
      <input
        type="text"
        value={formData.data}
        onChange={(e) => setFormData({ ...formData, data: e.target.value })}
        className="registry__input"
        maxLength={255}
        placeholder="Enter your data..."
      />
    )
  }

  return (
    <div className="registry">
      {/* Header */}
      <div className="registry__header">
        <FaClipboardList className="registry__header-icon registry__header-icon--lg" />
        <span className="registry__title">{registry.title}</span>
      </div>

      {/* Author and description */}
      <div className="registry__author-section">
        <span>Created by <LinkNode nodeId={registry.author.node_id} title={registry.author.title} /></span>
      </div>

      {registry.doctext && (
        <div
          className="registry__description"
          dangerouslySetInnerHTML={{ __html: renderE2Content(registry.doctext).html }}
        />
      )}

      {/* Message */}
      {message && (
        <div className={`registry__message ${message.type === 'error' ? 'registry__message--error' : 'registry__message--success'}`}>
          {message.text}
        </div>
      )}

      {/* Entry form */}
      <div className="registry__form-section">
        <h3 className="registry__section-title">
          <FaPlus className="registry__section-icon" />
          {userEntry ? 'Update Your Entry' : 'Submit Your Entry'}
        </h3>

        <form onSubmit={handleSubmit}>
          <div className="registry__form-row">
            <label className="registry__label">Your Data:</label>
            {renderInput()}
          </div>

          <div className="registry__form-row">
            <label className="registry__label">Comments (optional):</label>
            <textarea
              value={formData.comments}
              onChange={(e) => setFormData({ ...formData, comments: e.target.value })}
              className="registry__textarea"
              maxLength={512}
              placeholder="Add any comments..."
              rows={2}
            />
            <div className="registry__char-count">{512 - formData.comments.length} chars left</div>
          </div>

          <div className="registry__form-row">
            <label className="registry__checkbox-label">
              <input
                type="checkbox"
                checked={formData.in_user_profile}
                onChange={(e) => setFormData({ ...formData, in_user_profile: e.target.checked })}
              />
              Show in your profile?
            </label>
          </div>

          <div className="registry__button-row">
            <button type="submit" className="registry__submit-button" disabled={isSubmitting}>
              <FaCheck className="registry__submit-icon" />
              {isSubmitting ? 'Submitting...' : 'Submit'}
            </button>

            {userEntry && (
              <button
                type="button"
                onClick={handleDeleteOwn}
                className="registry__delete-button"
                disabled={isSubmitting}
              >
                <FaTimes className="registry__submit-icon" />
                Remove My Entry
              </button>
            )}
          </div>
        </form>
      </div>

      {/* Entries table */}
      <div className="registry__entries-section">
        <h3 className="registry__section-title">
          <FaUser className="registry__section-icon" />
          All Entries ({entries.length})
        </h3>

        {entries.length === 0 ? (
          <div className="registry__empty-state">
            No users have submitted information to this registry yet.
          </div>
        ) : (
          <div className="registry__table-wrapper">
            <table className="registry__table">
              <thead>
                <tr>
                  <th className="registry__th">User</th>
                  <th className="registry__th">Data</th>
                  <th className="registry__th">As of</th>
                  <th className="registry__th">Comments</th>
                  <th className="registry__th">Profile?</th>
                  {!!is_admin && <th className="registry__th">Actions</th>}
                </tr>
              </thead>
              <tbody>
                {entries.map((entry) => (
                  <tr key={entry.user_id} className="registry__tr">
                    <td className="registry__td">
                      <LinkNode nodeId={entry.user_id} title={entry.username} />
                    </td>
                    <td
                      className="registry__td"
                      dangerouslySetInnerHTML={{ __html: renderE2Content(entry.data || '').html }}
                    />
                    <td className="registry__td">{entry.timestamp}</td>
                    <td
                      className="registry__td"
                      dangerouslySetInnerHTML={{ __html: entry.comments ? renderE2Content(entry.comments).html : '-' }}
                    />
                    <td className="registry__td">{entry.in_user_profile ? 'Yes' : 'No'}</td>
                    {!!is_admin && (
                      <td className="registry__td">
                        <button
                          onClick={() => handleAdminDelete(entry.user_id, entry.username)}
                          className="registry__admin-delete-button"
                          title={`Delete entry for ${entry.username}`}
                          disabled={isSubmitting}
                        >
                          <FaTrash />
                        </button>
                      </td>
                    )}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Footer link */}
      <div className="registry__footer">
        <LinkNode nodeId={null} title="Recent Registry Entries">What are other people saying?</LinkNode>
      </div>
    </div>
  )
}

export default Registry
