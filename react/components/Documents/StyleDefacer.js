import React, { useState } from 'react'

/**
 * StyleDefacer - Custom CSS editor
 * Styles in CSS: .style-defacer__*
 *
 * Allows users to add custom CSS styles that override the default theme.
 * Note: This will eventually be migrated to use CSS variables.
 */
const StyleDefacer = ({ data }) => {
  const {
    error,
    customstyle = '',
    nirvana_id
  } = data

  const [styleValue, setStyleValue] = useState(customstyle)
  const [saved, setSaved] = useState(false)
  const [saveError, setSaveError] = useState(null)

  if (error) {
    return <div className="error-message">{error}</div>
  }

  // The custom CSS now persists via the preferences API (was a render-time
  // setVars from a ?vandalism POST param, #4416). The length cap lives server-side
  // in the allowlist; submitting an empty textarea clears the style.
  const handleSubmit = async (e) => {
    e.preventDefault()
    setSaveError(null)
    try {
      const res = await fetch('/api/preferences/set', {
        method: 'POST',
        credentials: 'same-origin',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify({ customstyle: styleValue })
      })
      if (res.ok) {
        setSaved(true)
      } else {
        setSaved(false)
        setSaveError('Your custom styles could not be saved — the CSS may be too long (50,000 character max).')
      }
    } catch (err) {
      setSaved(false)
      setSaveError('Network error saving your custom styles.')
    }
  }

  return (
    <div className="style-defacer">
      <p>
        So you're not satisfied with{' '}
        {nirvana_id ? (
          <a href={`/?node_id=${nirvana_id}`}>the beautiful styles lovingly crafted for you by the best designers on E2</a>
        ) : (
          'the beautiful styles lovingly crafted for you by the best designers on E2'
        )}
        ? Thought not. I bet you want to change all the colours, add low-res
        background images and generally MySpacify it. Well, don't ever say we're
        not good to you. This form right here will let you add any styles that
        you want, which will then override those in the theme.
      </p>

      {saved && (
        <div className="style-defacer__success">
          Your custom styles have been saved! Refresh the page to see changes.
        </div>
      )}
      {saveError && (
        <div className="style-defacer__error">{saveError}</div>
      )}

      <form onSubmit={handleSubmit}>
        <textarea
          id="vandalism"
          rows={40}
          value={styleValue}
          onChange={(e) => setStyleValue(e.target.value)}
          className="style-defacer__textarea"
          placeholder="/* Enter your custom CSS here */

/* Example: Change link colors */
a { color: #ff6600; }

/* Example: Change background */
body { background-color: #1a1a1a; }"
        />
        <br />

        <button type="submit" className="style-defacer__submit">
          Throw that paint
        </button>
      </form>

      <div className="style-defacer__tips">
        <p><strong>Tips:</strong></p>
        <ul>
          <li>Your custom CSS is applied after the theme CSS, so it will override theme styles.</li>
          <li>Use your browser's developer tools (F12) to inspect elements and find their CSS selectors.</li>
          <li>Clear this field entirely to remove all custom styles.</li>
          <li>Changes take effect on the next page load.</li>
        </ul>
      </div>
    </div>
  )
}

export default StyleDefacer
