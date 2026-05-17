import React from 'react'

/**
 * ThemeNirvana - Popular stylesheets browser
 *
 * Displays list of stylesheets for the zen theme in order of popularity.
 * Users can view their current style, test other styles, and access
 * customization tools.
 *
 * Styles in CSS: .theme-nirvana__*
 */
const ThemeNirvana = ({ data }) => {
  const {
    stylesheets = [],
    current_style,
    has_custom_style,
    is_guest
  } = data || {}

  return (
    <div className="theme-nirvana">
      <p className="theme-nirvana__intro">
        The following is a list of <a href="/title/stylesheet" className="theme-nirvana__link">stylesheets</a> for
        the <a href="/title/zen%20theme" className="theme-nirvana__link">zen theme</a> in order of popularity.
        You can find additional zen themes on <a href="/title/The%20Catwalk" className="theme-nirvana__link">The Catwalk</a>.
      </p>

      {current_style && (
        <div className="theme-nirvana__current-style">
          Your current stylesheet is{' '}
          <a href={`/node/${current_style.node_id}`} className="theme-nirvana__link">
            {current_style.title}
          </a>.
        </div>
      )}

      {has_custom_style ? (
        <div className="theme-nirvana__custom-warning">
          Note that you have customised your style using the{' '}
          <a href="/title/style%20defacer" className="theme-nirvana__link">style defacer</a> or{' '}
          <a href="/title/ekw%20Shredder" className="theme-nirvana__link">ekw Shredder</a>,
          which is going to affect the formatting of any stylesheet you choose.{' '}
          <a href="?clearVandalism=true" className="theme-nirvana__link">Click here to clear that out</a>{' '}
          if that's not what you want. If you want to create a whole new stylesheet,
          visit <a href="/title/the%20draughty%20atelier" className="theme-nirvana__link">the draughty atelier</a>.
        </div>
      ) : (
        <p className="theme-nirvana__intro">
          You can also customise your stylesheet at the{' '}
          <a href="/title/style%20defacer" className="theme-nirvana__link">style defacer</a> or
          create a whole new stylesheet at{' '}
          <a href="/title/the%20draughty%20atelier" className="theme-nirvana__link">the draughty atelier</a>.
        </p>
      )}

      <table className="theme-nirvana__table">
        <thead>
          <tr>
            <th className="theme-nirvana__th">Stylesheet Name</th>
            <th className="theme-nirvana__th theme-nirvana__th--center">Author</th>
            <th className="theme-nirvana__th theme-nirvana__th--right">Number of Users</th>
            <th className="theme-nirvana__th theme-nirvana__th--narrow">&nbsp;</th>
          </tr>
        </thead>
        <tbody>
          {stylesheets.map((style, idx) => {
            const isOdd = idx % 2 === 1
            const tdClass = `theme-nirvana__td${isOdd ? ' theme-nirvana__td--odd' : ''}`

            return (
              <tr key={style.node_id}>
                <td className={tdClass}>
                  <a href={`/node/${style.node_id}`} className="theme-nirvana__link">
                    {style.title}
                  </a>
                </td>
                <td className={`${tdClass} theme-nirvana__td--center`}>
                  {style.author ? (
                    <a href={`/node/${style.author.node_id}`} className="theme-nirvana__link">
                      {style.author.title}
                    </a>
                  ) : (
                    <span className="theme-nirvana__no-author">—</span>
                  )}
                </td>
                <td className={`${tdClass} theme-nirvana__td--right`}>
                  {style.user_count}
                </td>
                <td className={tdClass}>
                  {!is_guest && (
                    <a
                      href={`/title/Settings?trytheme=${style.node_id}`}
                      className="theme-nirvana__test-link"
                    >
                      [ test ]
                    </a>
                  )}
                </td>
              </tr>
            )
          })}
        </tbody>
      </table>
    </div>
  )
}

export default ThemeNirvana
