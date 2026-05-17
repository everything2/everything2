import React, { useState, useCallback } from 'react'

/**
 * AdminBestowTool - Unified admin tool for granting resources to users
 *
 * A configurable component that provides a consistent UI for all admin
 * resource granting functions (GP, XP, cools, easter eggs, teddy hugs, etc.)
 *
 * Props from data:
 * - type: Tool type identifier for API routing
 * - title: Display title for the tool
 * - description: Help text explaining what this tool does
 * - permission_error: Message shown if user lacks permission
 * - has_permission: Whether current user can use this tool
 * - resource_name: What's being granted (e.g., "GP", "XP", "cools", "easter eggs")
 * - fixed_amount: If set, grants this fixed amount per user (no amount input shown)
 * - show_amount_input: Whether to show an amount input field per user
 * - default_amount: Default value for amount input (if show_amount_input is true)
 * - allow_negative: Whether negative amounts are allowed (for curses/penalties)
 * - row_count: Number of user input rows to show (default 5)
 * - api_endpoint: API endpoint to call (e.g., "/api/superbless/grant_gp")
 * - button_text: Text for submit button (default "Submit")
 * - button_text_loading: Text while submitting (default "Processing...")
 * - note_text: Optional note text shown at bottom of form
 * - prefill_username: Username to pre-fill in the first row (for self-service tools)
 */
const AdminBestowTool = ({ data, user }) => {
  const {
    type,
    title,
    description,
    intro_text,
    permission_error,
    has_permission,
    resource_name,
    fixed_amount,
    show_amount_input,
    default_amount,
    allow_negative,
    row_count = 5,
    api_endpoint,
    button_text = 'Submit',
    button_text_loading = 'Processing...',
    note_text,
    prefill_username
  } = data

  // Initialize rows with usernames and optional amounts
  const createEmptyRows = useCallback(() => {
    return Array(row_count).fill(null).map((_, index) => ({
      username: (index === 0 && prefill_username) ? prefill_username : '',
      amount: default_amount || ''
    }))
  }, [row_count, default_amount, prefill_username])

  const [rows, setRows] = useState(() => createEmptyRows())
  const [results, setResults] = useState([])
  const [loading, setLoading] = useState(false)

  const updateRow = useCallback((index, field, value) => {
    setRows(prev => {
      const newRows = [...prev]
      newRows[index] = { ...newRows[index], [field]: value }
      return newRows
    })
  }, [])

  const handleSubmit = useCallback(async (e) => {
    e.preventDefault()

    // Filter to rows with usernames
    const filledRows = rows.filter(row => row.username.trim())
    if (filledRows.length === 0) {
      return
    }

    setLoading(true)
    setResults([])

    try {
      const payload = {
        users: filledRows.map(row => ({
          username: row.username.trim(),
          amount: fixed_amount !== undefined ? fixed_amount : (parseInt(row.amount, 10) || 0)
        }))
      }

      const response = await fetch(api_endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(payload)
      })

      const responseData = await response.json()

      if (response.ok) {
        setResults(responseData.results || [])
        // Clear the form on success
        setRows(createEmptyRows())
      } else {
        setResults([{ error: responseData.error || 'Failed to process request' }])
      }
    } catch (err) {
      setResults([{ error: 'Network error: ' + err.message }])
    } finally {
      setLoading(false)
    }
  }, [rows, api_endpoint, fixed_amount, createEmptyRows])

  // Permission check
  if (!has_permission) {
    return (
      <div className="admin-bestow">
        <p className="admin-bestow__permission-error">
          {permission_error || 'You do not have permission to use this tool.'}
        </p>
      </div>
    )
  }

  return (
    <div className="admin-bestow">
      {intro_text && (
        <p className="admin-bestow__intro">
          <strong>{intro_text}</strong>
        </p>
      )}

      {description && (
        <div className="admin-bestow__description">
          {description}
        </div>
      )}

      <form onSubmit={handleSubmit}>
        <table className="admin-bestow__table">
          <thead>
            <tr>
              <th className="admin-bestow__th">Username</th>
              {!!show_amount_input && (
                <th className="admin-bestow__th admin-bestow__th--narrow">{resource_name}</th>
              )}
            </tr>
          </thead>
          <tbody>
            {rows.map((row, index) => (
              <tr key={index}>
                <td className="admin-bestow__td">
                  <input
                    type="text"
                    value={row.username}
                    onChange={(e) => updateRow(index, 'username', e.target.value)}
                    className="admin-bestow__input userComplete"
                    placeholder="Enter username"
                    disabled={loading}
                  />
                </td>
                {!!show_amount_input && (
                  <td className="admin-bestow__td admin-bestow__td--narrow">
                    <input
                      type="number"
                      value={row.amount}
                      onChange={(e) => updateRow(index, 'amount', e.target.value)}
                      className="admin-bestow__input admin-bestow__input--amount"
                      placeholder="0"
                      disabled={loading}
                      min={allow_negative ? undefined : 0}
                    />
                  </td>
                )}
              </tr>
            ))}
          </tbody>
        </table>

        <button
          type="submit"
          className={`admin-bestow__button ${loading ? 'admin-bestow__button--disabled' : ''}`}
          disabled={loading}
        >
          {loading ? button_text_loading : button_text}
        </button>
      </form>

      {note_text && (
        <div className="admin-bestow__note">
          <strong>Note:</strong> {note_text}
        </div>
      )}

      {results.length > 0 && (
        <div className="admin-bestow__results">
          <h4 className="admin-bestow__results-title">Results:</h4>
          {results.map((result, index) => (
            <div key={index} className={result.success ? 'admin-bestow__result--success' : 'admin-bestow__result--error'}>
              {result.error ? (
                <span>✗ {result.error}</span>
              ) : result.success ? (
                <span>✓ {result.message}</span>
              ) : (
                <span>✗ {result.username}: {result.error}</span>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

export default AdminBestowTool
