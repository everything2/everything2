import React from 'react'

/**
 * PublishAsPicker - "Publish as another user" selector (canpublishas, #4354)
 *
 * Eligible users may cede authorship of a published writeup to a system
 * account (e.g. publish anonymously as "everyone", or as a bot). The list of
 * allowed accounts comes from GET /api/drafts/publishas_options. For most
 * users that list is empty, in which case this component renders nothing.
 *
 * The picker defaults to a blank "(yourself)" option. Selecting any other
 * account surfaces the legacy cede-copyright warning.
 *
 * Props:
 * - options: [{ title, node_id }] from the publishas_options endpoint
 * - value: the currently selected account title ('' = yourself)
 * - onChange: (title: string) => void
 * - disabled: optional, disables the select
 * - className: optional BEM block override (defaults to 'publish-as')
 */
const PublishAsPicker = ({
  options = [],
  value = '',
  onChange,
  disabled = false,
  className = 'publish-as'
}) => {
  // Common case: nothing to choose, render nothing.
  if (!options || options.length === 0) {
    return null
  }

  const handleChange = (e) => {
    if (onChange) onChange(e.target.value)
  }

  return (
    <div className={`${className}`}>
      <label className={`${className}__label`}>
        <span className={`${className}__label-text`}>Publish as:</span>
        <select
          value={value}
          onChange={handleChange}
          disabled={disabled}
          className={`${className}__select`}
        >
          <option value="">(yourself)</option>
          {options.map((opt) => (
            <option key={opt.node_id} value={opt.title}>
              {opt.title}
            </option>
          ))}
        </select>
      </label>

      {value && (
        <p className={`${className}__warning`}>
          By publishing to a different account you cede your copyright and lose
          all control over your writeup.
        </p>
      )}
    </div>
  )
}

export default PublishAsPicker
