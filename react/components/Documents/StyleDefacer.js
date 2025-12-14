import React, { useState } from 'react'

/**
 * StyleDefacer - Custom CSS editor
 *
 * Allows users to add custom CSS styles that override the default theme.
 * Note: This will eventually be migrated to use CSS variables.
 */
const StyleDefacer = ({ data }) => {
  const {
    error,
    node_id,
    customstyle = '',
    shredder_id,
    nirvana_id
  } = data

  const [styleValue, setStyleValue] = useState(customstyle)
  const [saved, setSaved] = useState(false)

  if (error) {
    return <div className="error-message">{error}</div>
  }

  const handleSubmit = (e) => {
    setSaved(true)
    // Form will submit normally
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

      <p>
        If you used to use ekw theme and fear change, then perhaps you'd like
        to start by using the{' '}
        {shredder_id ? (
          <a href={`/?node_id=${shredder_id}`}>ekw shredder</a>
        ) : (
          'ekw shredder'
        )}
        , which will attempt to create a custom style based on your old EKW settings.
      </p>

      <p>
        You need at least a small amount of knowledge of CSS to edit these, but
        if you start with a Shredded ekw style you should be able to simply edit
        the colours in that, or otherwise use it as a starting point. One day we
        may have an easier way to edit this. Perhaps after ascorbic retires.
      </p>

      {saved && (
        <div style={{
          padding: '10px',
          backgroundColor: '#d4edda',
          border: '1px solid #c3e6cb',
          borderRadius: '4px',
          marginBottom: '15px',
          color: '#155724'
        }}>
          Your custom styles have been saved! Refresh the page to see changes.
        </div>
      )}

      <form method="POST" action={`/?node_id=${node_id}`} onSubmit={handleSubmit}>
        <input type="hidden" name="node_id" value={node_id} />

        <textarea
          id="vandalism"
          name="vandalism"
          rows={40}
          value={styleValue}
          onChange={(e) => setStyleValue(e.target.value)}
          style={{
            width: '100%',
            fontFamily: 'monospace',
            fontSize: '13px'
          }}
          placeholder="/* Enter your custom CSS here */

/* Example: Change link colors */
a { color: #ff6600; }

/* Example: Change background */
body { background-color: #1a1a1a; }"
        />
        <br />

        <button
          type="submit"
          style={{
            marginTop: '10px',
            padding: '8px 20px',
            backgroundColor: '#38495e',
            color: '#fff',
            border: 'none',
            borderRadius: '3px',
            cursor: 'pointer'
          }}
        >
          Throw that paint
        </button>
      </form>

      <div style={{ marginTop: '20px', color: '#666', fontSize: '12px' }}>
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
