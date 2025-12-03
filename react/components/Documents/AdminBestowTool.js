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

  const containerStyle = {
    padding: '20px',
    maxWidth: '700px'
  }

  const tableStyle = {
    borderCollapse: 'collapse',
    width: '100%',
    marginBottom: '20px'
  }

  const thStyle = {
    backgroundColor: '#38495e',
    color: '#ffffff',
    padding: '10px',
    textAlign: 'left',
    border: '1px solid #38495e'
  }

  const tdStyle = {
    border: '1px solid #d3d3d3',
    padding: '8px'
  }

  const inputStyle = {
    width: '100%',
    padding: '8px',
    border: '1px solid #d3d3d3',
    borderRadius: '3px',
    boxSizing: 'border-box'
  }

  const amountInputStyle = {
    ...inputStyle,
    width: '80px',
    textAlign: 'center'
  }

  const buttonStyle = {
    padding: '10px 20px',
    backgroundColor: loading ? '#c5cdd7' : '#38495e',
    color: '#ffffff',
    border: 'none',
    borderRadius: '3px',
    cursor: loading ? 'not-allowed' : 'pointer',
    fontSize: '14px',
    fontWeight: 'bold'
  }

  const resultStyle = {
    marginTop: '20px',
    padding: '15px',
    backgroundColor: '#f8f9f9',
    borderRadius: '5px'
  }

  const successStyle = {
    color: '#228b22',
    marginBottom: '5px'
  }

  const errorStyle = {
    color: '#8b0000',
    marginBottom: '5px'
  }

  const descriptionStyle = {
    marginBottom: '20px',
    padding: '15px',
    backgroundColor: '#f8f9f9',
    borderLeft: '3px solid #38495e',
    borderRadius: '3px',
    color: '#507898'
  }

  const noteStyle = {
    marginTop: '20px',
    padding: '15px',
    backgroundColor: '#f8f9f9',
    border: '1px solid #d3d3d3',
    borderRadius: '4px',
    fontSize: '13px',
    color: '#507898'
  }

  // Permission check
  if (!has_permission) {
    return (
      <div style={containerStyle}>
        <p style={{ color: '#8b0000', fontWeight: 'bold' }}>
          {permission_error || 'You do not have permission to use this tool.'}
        </p>
      </div>
    )
  }

  const introStyle = {
    fontStyle: 'italic',
    marginBottom: '20px'
  }

  return (
    <div style={containerStyle}>
      {intro_text && (
        <p style={introStyle}>
          <strong>{intro_text}</strong>
        </p>
      )}

      {description && (
        <div style={descriptionStyle}>
          {description}
        </div>
      )}

      <form onSubmit={handleSubmit}>
        <table style={tableStyle}>
          <thead>
            <tr>
              <th style={thStyle}>Username</th>
              {!!show_amount_input && (
                <th style={{ ...thStyle, width: '120px' }}>{resource_name}</th>
              )}
            </tr>
          </thead>
          <tbody>
            {rows.map((row, index) => (
              <tr key={index}>
                <td style={tdStyle}>
                  <input
                    type="text"
                    value={row.username}
                    onChange={(e) => updateRow(index, 'username', e.target.value)}
                    style={inputStyle}
                    placeholder="Enter username"
                    disabled={loading}
                    className="userComplete"
                  />
                </td>
                {!!show_amount_input && (
                  <td style={{ ...tdStyle, width: '120px' }}>
                    <input
                      type="number"
                      value={row.amount}
                      onChange={(e) => updateRow(index, 'amount', e.target.value)}
                      style={amountInputStyle}
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
          style={buttonStyle}
          disabled={loading}
        >
          {loading ? button_text_loading : button_text}
        </button>
      </form>

      {note_text && (
        <div style={noteStyle}>
          <strong>Note:</strong> {note_text}
        </div>
      )}

      {results.length > 0 && (
        <div style={resultStyle}>
          <h4 style={{ marginTop: 0, color: '#38495e' }}>Results:</h4>
          {results.map((result, index) => (
            <div key={index} style={result.success ? successStyle : errorStyle}>
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
