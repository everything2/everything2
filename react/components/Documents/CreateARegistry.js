import React from 'react'
import RegistryFooter from '../shared/RegistryFooter'

/**
 * CreateARegistry - Form to create a new registry
 * Styles in CSS: .create-registry__*
 * Requires level 8+ to create registries
 */
const CreateARegistry = ({ data }) => {
  const {
    can_create,
    is_guest,
    level_required,
    current_level,
    input_styles = ['text', 'yes/no', 'date']
  } = data

  const [title, setTitle] = React.useState('')
  const [description, setDescription] = React.useState('')
  const [inputStyle, setInputStyle] = React.useState('text')

  // Guest message
  if (is_guest) {
    return (
      <div className="create-registry">
        <p className="create-registry__guest-message">
          You must be logged in to create a registry.
        </p>
      </div>
    )
  }

  // Level requirement not met
  if (level_required) {
    return (
      <div className="create-registry">
        <div className="create-registry__intro">
          <p>Registries are places where people can share snippets of information about themselves, like their email address or favourite vegetables.</p>
          <p>Before you create any new registries, you should have a look at <a href="/title/The+Registries" className="create-registry__link">the registries</a> we already have.</p>
        </div>
        <div className="create-registry__level-warning">
          <p>You would need to be <a href="/title/The+Everything2+Voting%2FExperience+System" className="create-registry__link">level {level_required}</a> to create a registry.</p>
          {current_level > 0 && (
            <p className="create-registry__current-level">Your current level: {current_level}</p>
          )}
        </div>
      </div>
    )
  }

  // Can create registry - show form
  return (
    <div className="create-registry">
      <div className="create-registry__intro">
        <p>Registries are places where people can share snippets of information about themselves, like their email address or favourite vegetables.</p>
        <p>Before you create any new registries, you should have a look at <a href="/title/The+Registries" className="create-registry__link">the registries</a> we already have.</p>
      </div>

      <form method="POST" action="/" className="create-registry__form">
        <input type="hidden" name="op" value="new" />
        <input type="hidden" name="type" value="registry" />
        <input type="hidden" name="displaytype" value="display" />

        <table className="create-registry__table">
          <tbody>
            <tr>
              <td className="create-registry__label-cell">Title</td>
              <td className="create-registry__input-cell">
                <input
                  type="text"
                  name="node"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  className="create-registry__text-input"
                  maxLength={255}
                  required
                />
              </td>
            </tr>
            <tr>
              <td className="create-registry__label-cell">Description</td>
              <td className="create-registry__input-cell">
                <textarea
                  name="registry_doctext"
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  className="create-registry__textarea"
                  rows={7}
                />
              </td>
            </tr>
            <tr>
              <td className="create-registry__label-cell">Answer style</td>
              <td className="create-registry__input-cell">
                <select
                  name="registry_input_style"
                  value={inputStyle}
                  onChange={(e) => setInputStyle(e.target.value)}
                  className="create-registry__select"
                >
                  {input_styles.map((style) => (
                    <option key={style} value={style}>{style}</option>
                  ))}
                </select>
              </td>
            </tr>
            <tr>
              <td className="create-registry__label-cell"></td>
              <td className="create-registry__input-cell">
                <button type="submit" name="sexisgood" value="create" className="create-registry__submit-button">
                  Create Registry
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </form>

      <RegistryFooter currentPage="create" />
    </div>
  )
}

export default CreateARegistry
