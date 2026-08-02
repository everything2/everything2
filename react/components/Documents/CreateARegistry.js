import React, { useState, useEffect } from 'react'
import RegistryFooter from '../shared/RegistryFooter'

/**
 * CreateARegistry - Form to create a new registry
 * Styles in CSS: .create-registry__*
 *
 * Fetch-driven (#4550): the Page is a pure gate; this fetches GET /api/create_a_registry for the
 * can-create/level gate (state:'guest' for guests). Creation POSTs to
 * /api/create_a_registry/create, which sets the registry's own fields -- the generic
 * /api/node/create could only take type+title (#4554). The answer-style options are display config
 * here, not server-shipped.
 */
const INPUT_STYLES = ['text', 'yes/no', 'date']

const CreateARegistry = () => {
  const [gate, setGate] = useState(null)
  const [loading, setLoading] = useState(true)

  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [inputStyle, setInputStyle] = useState('text')
  const [error, setError] = useState('')

  useEffect(() => {
    let cancelled = false
    fetch('/api/create_a_registry', { credentials: 'same-origin' })
      .then((r) => r.json())
      .then((j) => { if (!cancelled) { setGate(j); setLoading(false) } })
      .catch(() => { if (!cancelled) setLoading(false) })
    return () => { cancelled = true }
  }, [])

  // Create via the registry API, which sets the registry-specific fields. The generic
  // /api/node/create takes only type+title, so it silently dropped the description and the answer
  // style -- every registry came back free-text whatever you picked (#4554).
  const handleSubmit = async (e) => {
    e.preventDefault()
    setError('')
    try {
      const res = await fetch('/api/create_a_registry/create', {
        method: 'POST',
        credentials: 'same-origin',
        headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
        body: JSON.stringify({ title, description, input_style: inputStyle }),
      })
      const created = res.ok ? await res.json() : null
      if (created && created.success && created.node_id) {
        window.location.href = `/node/${created.node_id}`
        return
      }
      setError((created && created.error) || 'Could not create the registry')
    } catch (err) {
      setError('Network error: ' + err.message)
    }
  }

  if (loading) {
    return <div className="create-registry"><p>Loading...</p></div>
  }

  const { state, can_create, level_required, current_level } = gate || {}

  if (state === 'guest') {
    return (
      <div className="create-registry">
        <p className="create-registry__guest-message">
          You must be logged in to create a registry.
        </p>
      </div>
    )
  }

  if (!can_create) {
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

  return (
    <div className="create-registry">
      <div className="create-registry__intro">
        <p>Registries are places where people can share snippets of information about themselves, like their email address or favourite vegetables.</p>
        <p>Before you create any new registries, you should have a look at <a href="/title/The+Registries" className="create-registry__link">the registries</a> we already have.</p>
      </div>

      <form onSubmit={handleSubmit} className="create-registry__form">
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
                  {INPUT_STYLES.map((style) => (
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
                {error && <p className="create-registry__error">{error}</p>}
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
