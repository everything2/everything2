import React from 'react'

/**
 * ThemeNirvana - Popular stylesheets browser
 *
 * Displays list of stylesheets for the zen theme in order of popularity.
 * Users can view their current style, test other styles, and access
 * customization tools.
 */
const ThemeNirvana = ({ data }) => {
  const {
    stylesheets = [],
    current_style,
    has_custom_style,
    is_guest
  } = data || {}

  // Kernel Blue colors
  const colors = {
    primary: '#38495e',
    secondary: '#507898',
    highlight: '#4060b0',
    accent: '#3bb5c3',
    background: '#f8f9f9',
    text: '#111111'
  }

  // Styles
  const containerStyle = {
    padding: '20px',
    maxWidth: '1000px',
    margin: '0 auto'
  }

  const introStyle = {
    color: colors.text,
    lineHeight: '1.6',
    marginBottom: '20px'
  }

  const currentStyleStyle = {
    marginBottom: '20px',
    padding: '15px',
    backgroundColor: colors.background,
    borderRadius: '6px',
    borderLeft: `4px solid ${colors.accent}`
  }

  const customStyleWarningStyle = {
    marginBottom: '20px',
    padding: '15px',
    backgroundColor: '#fff8e1',
    borderRadius: '6px',
    border: '1px solid #ffcc02',
    lineHeight: '1.6'
  }

  const tableStyle = {
    width: '100%',
    borderCollapse: 'collapse',
    backgroundColor: '#fff',
    boxShadow: '0 1px 3px rgba(0,0,0,0.1)',
    borderRadius: '8px',
    overflow: 'hidden'
  }

  const thStyle = {
    backgroundColor: colors.primary,
    color: '#fff',
    padding: '12px 15px',
    textAlign: 'left',
    fontSize: '14px',
    fontWeight: '600'
  }

  const tdStyle = (isOdd) => ({
    padding: '12px 15px',
    borderBottom: '1px solid #eee',
    fontSize: '14px',
    backgroundColor: isOdd ? colors.background : '#fff'
  })

  const linkStyle = {
    color: colors.highlight,
    textDecoration: 'none',
    fontWeight: '500'
  }

  const testLinkStyle = {
    color: colors.secondary,
    textDecoration: 'none',
    fontSize: '13px'
  }

  return (
    <div style={containerStyle}>
      <p style={introStyle}>
        The following is a list of <a href="/title/stylesheet" style={linkStyle}>stylesheets</a> for
        the <a href="/title/zen%20theme" style={linkStyle}>zen theme</a> in order of popularity.
        You can find additional zen themes on <a href="/title/The%20Catwalk" style={linkStyle}>The Catwalk</a>.
      </p>

      {current_style && (
        <div style={currentStyleStyle}>
          Your current stylesheet is{' '}
          <a href={`/node/${current_style.node_id}`} style={linkStyle}>
            {current_style.title}
          </a>.
        </div>
      )}

      {has_custom_style ? (
        <div style={customStyleWarningStyle}>
          Note that you have customised your style using the{' '}
          <a href="/title/style%20defacer" style={linkStyle}>style defacer</a> or{' '}
          <a href="/title/ekw%20Shredder" style={linkStyle}>ekw Shredder</a>,
          which is going to affect the formatting of any stylesheet you choose.{' '}
          <a href="?clearVandalism=true" style={linkStyle}>Click here to clear that out</a>{' '}
          if that's not what you want. If you want to create a whole new stylesheet,
          visit <a href="/title/the%20draughty%20atelier" style={linkStyle}>the draughty atelier</a>.
        </div>
      ) : (
        <p style={introStyle}>
          You can also customise your stylesheet at the{' '}
          <a href="/title/style%20defacer" style={linkStyle}>style defacer</a> or
          create a whole new stylesheet at{' '}
          <a href="/title/the%20draughty%20atelier" style={linkStyle}>the draughty atelier</a>.
        </p>
      )}

      <table style={tableStyle}>
        <thead>
          <tr>
            <th style={thStyle}>Stylesheet Name</th>
            <th style={{ ...thStyle, textAlign: 'center' }}>Author</th>
            <th style={{ ...thStyle, textAlign: 'right', width: '130px' }}>Number of Users</th>
            <th style={{ ...thStyle, width: '60px' }}>&nbsp;</th>
          </tr>
        </thead>
        <tbody>
          {stylesheets.map((style, idx) => (
            <tr key={style.node_id}>
              <td style={tdStyle(idx % 2 === 1)}>
                <a href={`/node/${style.node_id}`} style={linkStyle}>
                  {style.title}
                </a>
              </td>
              <td style={{ ...tdStyle(idx % 2 === 1), textAlign: 'center' }}>
                {style.author ? (
                  <a href={`/node/${style.author.node_id}`} style={linkStyle}>
                    {style.author.title}
                  </a>
                ) : (
                  <span style={{ color: '#999' }}>—</span>
                )}
              </td>
              <td style={{ ...tdStyle(idx % 2 === 1), textAlign: 'right' }}>
                {style.user_count}
              </td>
              <td style={tdStyle(idx % 2 === 1)}>
                {!is_guest && (
                  <a
                    href={`/title/Settings?trytheme=${style.node_id}`}
                    style={testLinkStyle}
                  >
                    [ test ]
                  </a>
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

export default ThemeNirvana
