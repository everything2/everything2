import React, { useState, useEffect } from 'react'
import LinkNode from '../LinkNode'
import { FaClipboardList, FaTimes, FaPlus, FaCheck, FaTrash, FaUser } from 'react-icons/fa'
import { renderE2Content } from '../Editor/E2HtmlSanitizer'

/**
 * Registry - Display and manage registry entries
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
      <div style={styles.container}>
        <div style={styles.header}>
          <FaClipboardList style={{ color: '#507898', marginRight: 8 }} />
          <span style={styles.title}>{registry.title}</span>
        </div>

        <div style={styles.guestMessage}>
          <p style={{ textAlign: 'center', fontWeight: 'bold', marginBottom: 16 }}>
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
        <div style={{ display: 'flex', gap: 8 }}>
          <select
            value={formData.year}
            onChange={(e) => setFormData({ ...formData, year: e.target.value })}
            style={styles.select}
          >
            {years.map(y => (
              <option key={y} value={y}>{y === 'secret' ? 'Year (secret)' : y}</option>
            ))}
          </select>
          <select
            value={formData.month}
            onChange={(e) => setFormData({ ...formData, month: parseInt(e.target.value, 10) })}
            style={styles.select}
          >
            {months.map(m => (
              <option key={m} value={m}>{String(m).padStart(2, '0')}</option>
            ))}
          </select>
          <select
            value={formData.day}
            onChange={(e) => setFormData({ ...formData, day: parseInt(e.target.value, 10) })}
            style={styles.select}
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
          style={styles.select}
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
        style={styles.input}
        maxLength={255}
        placeholder="Enter your data..."
      />
    )
  }

  return (
    <div style={styles.container}>
      {/* Header */}
      <div style={styles.header}>
        <FaClipboardList style={{ color: '#507898', marginRight: 8, fontSize: 20 }} />
        <span style={styles.title}>{registry.title}</span>
      </div>

      {/* Author and description */}
      <div style={styles.authorSection}>
        <span>Created by <LinkNode nodeId={registry.author.node_id} title={registry.author.title} /></span>
      </div>

      {registry.doctext && (
        <div
          style={styles.description}
          dangerouslySetInnerHTML={{ __html: renderE2Content(registry.doctext).html }}
        />
      )}

      {/* Message */}
      {message && (
        <div style={{
          ...styles.message,
          backgroundColor: message.type === 'error' ? '#fee' : '#efe',
          color: message.type === 'error' ? '#c00' : '#060'
        }}>
          {message.text}
        </div>
      )}

      {/* Entry form */}
      <div style={styles.formSection}>
        <h3 style={styles.sectionTitle}>
          <FaPlus style={{ marginRight: 6 }} />
          {userEntry ? 'Update Your Entry' : 'Submit Your Entry'}
        </h3>

        <form onSubmit={handleSubmit}>
          <div style={styles.formRow}>
            <label style={styles.label}>Your Data:</label>
            {renderInput()}
          </div>

          <div style={styles.formRow}>
            <label style={styles.label}>Comments (optional):</label>
            <textarea
              value={formData.comments}
              onChange={(e) => setFormData({ ...formData, comments: e.target.value })}
              style={styles.textarea}
              maxLength={512}
              placeholder="Add any comments..."
              rows={2}
            />
            <div style={styles.charCount}>{512 - formData.comments.length} chars left</div>
          </div>

          <div style={styles.formRow}>
            <label style={styles.checkboxLabel}>
              <input
                type="checkbox"
                checked={formData.in_user_profile}
                onChange={(e) => setFormData({ ...formData, in_user_profile: e.target.checked })}
              />
              Show in your profile?
            </label>
          </div>

          <div style={styles.buttonRow}>
            <button type="submit" style={styles.submitButton} disabled={isSubmitting}>
              <FaCheck style={{ marginRight: 4 }} />
              {isSubmitting ? 'Submitting...' : 'Submit'}
            </button>

            {userEntry && (
              <button
                type="button"
                onClick={handleDeleteOwn}
                style={styles.deleteButton}
                disabled={isSubmitting}
              >
                <FaTimes style={{ marginRight: 4 }} />
                Remove My Entry
              </button>
            )}
          </div>
        </form>
      </div>

      {/* Entries table */}
      <div style={styles.entriesSection}>
        <h3 style={styles.sectionTitle}>
          <FaUser style={{ marginRight: 6 }} />
          All Entries ({entries.length})
        </h3>

        {entries.length === 0 ? (
          <div style={styles.emptyState}>
            No users have submitted information to this registry yet.
          </div>
        ) : (
          <div style={styles.tableWrapper}>
            <table style={styles.table}>
              <thead>
                <tr>
                  <th style={styles.th}>User</th>
                  <th style={styles.th}>Data</th>
                  <th style={styles.th}>As of</th>
                  <th style={styles.th}>Comments</th>
                  <th style={styles.th}>Profile?</th>
                  {is_admin && <th style={styles.th}>Actions</th>}
                </tr>
              </thead>
              <tbody>
                {entries.map((entry) => (
                  <tr key={entry.user_id} style={styles.tr}>
                    <td style={styles.td}>
                      <LinkNode nodeId={entry.user_id} title={entry.username} />
                    </td>
                    <td
                      style={styles.td}
                      dangerouslySetInnerHTML={{ __html: renderE2Content(entry.data || '').html }}
                    />
                    <td style={styles.td}>{entry.timestamp}</td>
                    <td
                      style={styles.td}
                      dangerouslySetInnerHTML={{ __html: entry.comments ? renderE2Content(entry.comments).html : '-' }}
                    />
                    <td style={styles.td}>{entry.in_user_profile ? 'Yes' : 'No'}</td>
                    {is_admin && (
                      <td style={styles.td}>
                        <button
                          onClick={() => handleAdminDelete(entry.user_id, entry.username)}
                          style={styles.adminDeleteButton}
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
      <div style={styles.footer}>
        <LinkNode nodeId={null} title="Recent Registry Entries">What are other people saying?</LinkNode>
      </div>
    </div>
  )
}

const styles = {
  container: {
    maxWidth: 800,
    margin: '0 auto',
    padding: '16px 0'
  },
  header: {
    display: 'flex',
    alignItems: 'center',
    fontSize: 18,
    fontWeight: 'bold',
    color: '#38495e',
    marginBottom: 12
  },
  title: {
    flex: 1
  },
  authorSection: {
    textAlign: 'center',
    color: '#666',
    fontSize: 14,
    marginBottom: 16
  },
  description: {
    textAlign: 'center',
    padding: 16,
    marginBottom: 16,
    backgroundColor: '#f8f9fa',
    borderRadius: 4,
    lineHeight: 1.6
  },
  guestMessage: {
    padding: 24,
    textAlign: 'center',
    backgroundColor: '#fff3cd',
    border: '1px solid #ffc107',
    borderRadius: 4,
    color: '#856404'
  },
  message: {
    padding: 10,
    marginBottom: 16,
    borderRadius: 4,
    fontSize: 14
  },
  formSection: {
    backgroundColor: '#f8f9fa',
    border: '1px solid #ddd',
    borderRadius: 4,
    padding: 16,
    marginBottom: 24
  },
  sectionTitle: {
    display: 'flex',
    alignItems: 'center',
    fontSize: 14,
    fontWeight: 'bold',
    color: '#38495e',
    marginTop: 0,
    marginBottom: 16
  },
  formRow: {
    marginBottom: 12
  },
  label: {
    display: 'block',
    marginBottom: 4,
    fontWeight: 'bold',
    fontSize: 13,
    color: '#38495e'
  },
  input: {
    width: '100%',
    padding: 8,
    border: '1px solid #ccc',
    borderRadius: 4,
    fontSize: 14,
    boxSizing: 'border-box'
  },
  textarea: {
    width: '100%',
    padding: 8,
    border: '1px solid #ccc',
    borderRadius: 4,
    fontSize: 14,
    resize: 'vertical',
    boxSizing: 'border-box'
  },
  select: {
    padding: 8,
    border: '1px solid #ccc',
    borderRadius: 4,
    fontSize: 14
  },
  charCount: {
    fontSize: 11,
    color: '#999',
    textAlign: 'right',
    marginTop: 4
  },
  checkboxLabel: {
    display: 'flex',
    alignItems: 'center',
    gap: 8,
    fontSize: 14,
    cursor: 'pointer'
  },
  buttonRow: {
    display: 'flex',
    gap: 12,
    marginTop: 16
  },
  submitButton: {
    display: 'flex',
    alignItems: 'center',
    padding: '8px 16px',
    backgroundColor: '#4060b0',
    color: '#fff',
    border: 'none',
    borderRadius: 4,
    cursor: 'pointer',
    fontSize: 14,
    fontWeight: 'bold'
  },
  deleteButton: {
    display: 'flex',
    alignItems: 'center',
    padding: '8px 16px',
    backgroundColor: '#507898',
    color: '#fff',
    border: 'none',
    borderRadius: 4,
    cursor: 'pointer',
    fontSize: 14
  },
  entriesSection: {
    marginBottom: 24
  },
  emptyState: {
    textAlign: 'center',
    padding: 24,
    color: '#999',
    fontStyle: 'italic',
    backgroundColor: '#f8f9fa',
    borderRadius: 4
  },
  tableWrapper: {
    overflowX: 'auto'
  },
  table: {
    width: '100%',
    borderCollapse: 'collapse',
    fontSize: 13
  },
  th: {
    textAlign: 'left',
    padding: '10px 8px',
    borderBottom: '2px solid #38495e',
    backgroundColor: '#f8f9fa',
    fontWeight: 'bold',
    color: '#38495e'
  },
  tr: {
    borderBottom: '1px solid #eee'
  },
  td: {
    padding: '10px 8px',
    verticalAlign: 'top'
  },
  adminDeleteButton: {
    background: 'none',
    border: 'none',
    color: '#507898',
    cursor: 'pointer',
    padding: 4,
    fontSize: 14
  },
  footer: {
    textAlign: 'center',
    padding: 16,
    fontWeight: 'bold'
  }
}

export default Registry
