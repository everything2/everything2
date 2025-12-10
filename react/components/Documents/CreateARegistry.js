import React from 'react'
import RegistryFooter from '../shared/RegistryFooter'

/**
 * CreateARegistry - Form to create a new registry
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
      <div style={styles.container}>
        <p style={styles.guestMessage}>
          You must be logged in to create a registry.
        </p>
      </div>
    )
  }

  // Level requirement not met
  if (level_required) {
    return (
      <div style={styles.container}>
        <div style={styles.intro}>
          <p>Registries are places where people can share snippets of information about themselves, like their email address or favourite vegetables.</p>
          <p>Before you create any new registries, you should have a look at <a href="/title/The+Registries" style={styles.link}>the registries</a> we already have.</p>
        </div>
        <div style={styles.levelWarning}>
          <p>You would need to be <a href="/title/The+Everything2+Voting%2FExperience+System" style={styles.link}>level {level_required}</a> to create a registry.</p>
          {current_level > 0 && (
            <p style={styles.currentLevel}>Your current level: {current_level}</p>
          )}
        </div>
      </div>
    )
  }

  // Can create registry - show form
  return (
    <div style={styles.container}>
      <div style={styles.intro}>
        <p>Registries are places where people can share snippets of information about themselves, like their email address or favourite vegetables.</p>
        <p>Before you create any new registries, you should have a look at <a href="/title/The+Registries" style={styles.link}>the registries</a> we already have.</p>
      </div>

      <form method="POST" action="/" style={styles.form}>
        <input type="hidden" name="op" value="new" />
        <input type="hidden" name="type" value="registry" />
        <input type="hidden" name="displaytype" value="display" />

        <table style={styles.table}>
          <tbody>
            <tr>
              <td style={styles.labelCell}>Title</td>
              <td style={styles.inputCell}>
                <input
                  type="text"
                  name="node"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  style={styles.textInput}
                  maxLength={255}
                  required
                />
              </td>
            </tr>
            <tr>
              <td style={styles.labelCell}>Description</td>
              <td style={styles.inputCell}>
                <textarea
                  name="registry_doctext"
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  style={styles.textarea}
                  rows={7}
                />
              </td>
            </tr>
            <tr>
              <td style={styles.labelCell}>Answer style</td>
              <td style={styles.inputCell}>
                <select
                  name="registry_input_style"
                  value={inputStyle}
                  onChange={(e) => setInputStyle(e.target.value)}
                  style={styles.select}
                >
                  {input_styles.map((style) => (
                    <option key={style} value={style}>{style}</option>
                  ))}
                </select>
              </td>
            </tr>
            <tr>
              <td style={styles.labelCell}></td>
              <td style={styles.inputCell}>
                <button type="submit" name="sexisgood" value="create" style={styles.submitButton}>
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

const styles = {
  container: {
    maxWidth: '700px',
    margin: '0 auto',
    padding: '20px'
  },
  intro: {
    marginBottom: '25px',
    color: '#38495e',
    lineHeight: '1.6'
  },
  guestMessage: {
    padding: '30px',
    fontStyle: 'italic',
    color: '#507898',
    textAlign: 'center',
    fontSize: '14px'
  },
  levelWarning: {
    padding: '20px',
    background: '#fff3cd',
    color: '#856404',
    border: '1px solid #ffc107',
    borderRadius: '4px',
    textAlign: 'center'
  },
  currentLevel: {
    marginTop: '10px',
    fontSize: '13px',
    fontStyle: 'italic'
  },
  form: {
    background: '#f8f9f9',
    padding: '20px',
    borderRadius: '4px',
    border: '1px solid #dee2e6'
  },
  table: {
    width: '100%',
    borderCollapse: 'collapse'
  },
  labelCell: {
    padding: '10px 15px 10px 0',
    verticalAlign: 'top',
    fontWeight: '600',
    color: '#38495e',
    width: '120px'
  },
  inputCell: {
    padding: '10px 0'
  },
  textInput: {
    width: '100%',
    padding: '8px 12px',
    fontSize: '14px',
    border: '1px solid #ced4da',
    borderRadius: '4px',
    boxSizing: 'border-box'
  },
  textarea: {
    width: '100%',
    padding: '8px 12px',
    fontSize: '14px',
    border: '1px solid #ced4da',
    borderRadius: '4px',
    boxSizing: 'border-box',
    resize: 'vertical'
  },
  select: {
    padding: '8px 12px',
    fontSize: '14px',
    border: '1px solid #ced4da',
    borderRadius: '4px',
    background: '#fff'
  },
  submitButton: {
    padding: '10px 24px',
    fontSize: '14px',
    fontWeight: '600',
    color: '#fff',
    background: '#38495e',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer'
  },
  link: {
    color: '#4060b0',
    textDecoration: 'none'
  }
}

export default CreateARegistry
