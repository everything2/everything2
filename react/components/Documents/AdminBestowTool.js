import React, { useState, useCallback } from 'react'

/**
 * TOOL_CONFIG - the flavor text + behavior for each bestow tool, keyed by document type.
 *
 * The Pages are pure gates that ship only { type } (#4509); React owns all presentation here.
 * `requires` names the permission tier the UI enforces for display; the API is the real
 * enforcement boundary. `intro_text` may be a function of the acting user (the teddy tools name
 * them). `prefill_self` fills the first row with the acting user (self-service well_of_cool).
 */
const TOOL_CONFIG = {
  bestow_cools: {
    requires: 'admin',
    permission_error: 'Only administrators can bestow cools.',
    title: 'Bestow Cools',
    description: 'Grant cools (C!) to users. Users can use cools to highlight excellent writeups.',
    resource_name: 'Cools',
    show_amount_input: true, allow_negative: false, default_amount: '1', row_count: 5,
    api_endpoint: '/api/superbless/grant_cools',
    button_text: 'Bestow Cools', button_text_loading: 'Bestowing...',
    note_text: 'Cools allow users to C! writeups they find excellent.'
  },
  bestow_easter_eggs: {
    requires: 'admin',
    permission_error: 'Who do you think you are? The Easter Bunny?',
    title: 'Bestow Easter Eggs',
    description: 'Grant easter eggs to users. Each user receives one easter egg per entry.',
    resource_name: 'Eggs',
    fixed_amount: 1, show_amount_input: false, row_count: 5,
    api_endpoint: '/api/easter_eggs/bestow',
    button_text: 'Bestow Easter Eggs', button_text_loading: 'Bestowing...',
    note_text: 'Each user receives one easter egg. Users get a message from Cool Man Eddie.'
  },
  enrichify: {
    requires: 'admin',
    permission_error: 'You want to be supercursed? No? Then play elsewhere.',
    title: 'Enrichify',
    description: 'Grant GP to users. Positive values give GP, negative values remove GP. Karma is adjusted accordingly.',
    resource_name: 'GP',
    show_amount_input: true, allow_negative: true, default_amount: '', row_count: 10,
    api_endpoint: '/api/superbless/grant_gp',
    button_text: 'Enrichify', button_text_loading: 'Enrichifying...',
    note_text: 'All GP grants are logged. Karma is adjusted based on the direction of the grant.'
  },
  fiery_teddy_bear_suit: {
    requires: 'admin',
    permission_error: 'Hands off the bear, bobo.',
    title: 'Fiery Teddy Bear Suit',
    description: 'The user(s) are publicly hugged by a Fiery Teddy Bear. Users are cursed with -1 GP and -1 karma.',
    intro_text: (user) => `${user?.title || 'Someone'} is engulfed in flames . . . OW!`,
    resource_name: 'GP',
    fixed_amount: -1, show_amount_input: false, row_count: 5,
    api_endpoint: '/api/superbless/fiery_hug',
    button_text: 'Hug Users', button_text_loading: 'Hugging...',
    note_text: 'Fiery hugs remove 1 GP and post a public hug message to the chatterbox.'
  },
  giant_teddy_bear_suit: {
    requires: 'admin',
    permission_error: 'Hands off the bear, bobo.',
    title: 'Giant Teddy Bear Suit',
    description: 'The user(s) are publicly hugged by a Giant Teddy Bear. Users receive +2 GP and +1 karma.',
    intro_text: (user) => `${user?.title || 'Someone'} has donned the Giant Teddy Bear Suit . . .`,
    resource_name: 'GP',
    fixed_amount: 2, show_amount_input: false, row_count: 5,
    api_endpoint: '/api/teddybear/hug',
    button_text: 'Hug Users', button_text_loading: 'Hugging...',
    note_text: 'Giant Teddy Bear hugs grant 2 GP and post a public hug message to the chatterbox.'
  },
  superbless: {
    requires: 'editor',
    permission_error: 'This tool is available to editors and administrators.',
    title: 'Superbless',
    description: 'Grant GP to users. Positive values give GP, negative values remove GP. Karma is adjusted accordingly.',
    resource_name: 'GP',
    show_amount_input: true, allow_negative: true, default_amount: '', row_count: 10,
    api_endpoint: '/api/superbless/grant_gp',
    button_text: 'Superbless', button_text_loading: 'Superblessing...',
    note_text: 'All GP grants are logged. Karma is adjusted based on the direction of the grant.'
  },
  xp_superbless: {
    requires: 'admin',
    permission_error: 'Only administrators can grant XP.',
    title: 'XP Superbless (Archived)',
    description: 'WARNING: This is an archived version of the old Superbless which used to give XP instead of GP. All blessings should be given in GP nowadays. There is no reason why administrators should fiddle with user XP except for extraordinary circumstances. All usage of this tool is logged. Please contact Tem42 if a user wants XP reset to zero.',
    resource_name: 'XP',
    show_amount_input: true, allow_negative: true, default_amount: '', row_count: 5,
    api_endpoint: '/api/superbless/grant_xp',
    button_text: 'Grant XP', button_text_loading: 'Granting XP...',
    note_text: 'All XP grants are logged and audited. Use [Superbless] for normal GP blessings.'
  },
  the_well_of_cool: {
    // Self-service: any user, first row prefilled with themselves.
    requires: null, prefill_self: true, permission_error: '',
    title: 'The Well of Cool',
    description: 'Drink deeply from the well of cool. Grant yourself cools (C!) to highlight excellent writeups.',
    resource_name: 'Cools',
    show_amount_input: true, allow_negative: false, default_amount: '1', row_count: 1,
    api_endpoint: '/api/superbless/grant_cools',
    button_text: 'Drink deeply from the well of cool', button_text_loading: 'Drinking...',
    note_text: 'Cools allow you to C! writeups you find excellent.'
  }
}

// Whether the acting user meets a tool's permission tier (admins count as editors).
const meetsRequirement = (requires, user) => {
  if (!requires) return true
  if (requires === 'admin') return !!user?.admin
  if (requires === 'editor') return !!user?.admin || !!user?.editor
  return false
}

/**
 * AdminBestowTool - Unified admin tool for granting resources to users.
 *
 * Config comes from TOOL_CONFIG keyed on data.type (the Page ships just { type }). A data.* path
 * is kept as a fallback for any external caller still shipping config inline (e.g. the fixture).
 */
const AdminBestowTool = ({ data, user }) => {
  const toolConfig = TOOL_CONFIG[data.type]
  const config = toolConfig || data

  const {
    title,
    description,
    permission_error,
    resource_name,
    fixed_amount,
    show_amount_input,
    default_amount,
    allow_negative,
    row_count = 5,
    api_endpoint,
    button_text = 'Submit',
    button_text_loading = 'Processing...',
    note_text
  } = config

  // intro_text may be a function of the acting user (the teddy tools name them).
  const intro_text = typeof config.intro_text === 'function' ? config.intro_text(user) : config.intro_text

  // Permission: config-driven tools compute the display flag from the actual user; legacy
  // data-driven consumers still ship has_permission. The API is the real enforcement boundary.
  const has_permission = toolConfig ? meetsRequirement(toolConfig.requires, user) : data.has_permission

  // prefill: self-service tools fill row 0 with the acting user; otherwise read ?prefill_username
  // off the URL (user-tools modal links pass it), with a legacy data.prefill_username fallback.
  const prefill_username = config.prefill_self
    ? (user?.title || '')
    : (data.prefill_username || new URLSearchParams(window.location.search).get('prefill_username') || '')

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
