import React, { useState, useCallback } from 'react'

/**
 * EditWeblogMenu - Configure weblog visibility and display options
 * Styles in CSS: .edit-weblog-menu__*
 */
const EditWeblogMenu = ({ data }) => {
  const { weblogs = [], nameifyWeblogs: initialNameify = false } = data || {}

  const [nameifyWeblogs, setNameifyWeblogs] = useState(initialNameify)
  const [weblogVisibility, setWeblogVisibility] = useState(() => {
    const initial = {}
    weblogs.forEach(w => {
      initial[w.node_id] = !w.hidden
    })
    return initial
  })
  const [saving, setSaving] = useState(false)
  const [message, setMessage] = useState(null)

  const handleWeblogToggle = useCallback((nodeId) => {
    setWeblogVisibility(prev => ({
      ...prev,
      [nodeId]: !prev[nodeId],
    }))
  }, [])

  const handleSubmit = useCallback(async (e) => {
    e.preventDefault()
    setSaving(true)
    setMessage(null)

    try {
      const response = await fetch('/api/weblogmenu/update', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({
          nameifyWeblogs,
          weblogs: weblogVisibility,
        }),
      })

      const result = await response.json()

      if (result.success) {
        setMessage({ type: 'success', text: 'Settings saved successfully!' })
      } else {
        setMessage({ type: 'error', text: result.error || 'Failed to save settings' })
      }
    } catch (err) {
      setMessage({ type: 'error', text: 'Failed to connect to server' })
    } finally {
      setSaving(false)
    }
  }, [nameifyWeblogs, weblogVisibility])

  const getWeblogTitle = useCallback((weblog) => {
    return nameifyWeblogs ? weblog.dynamicTitle : weblog.staticTitle
  }, [nameifyWeblogs])

  if (weblogs.length === 0) {
    return (
      <div className="edit-weblog-menu">
        <div className="edit-weblog-menu__header">
          <h1 className="edit-weblog-menu__title">Edit Weblog Menu</h1>
        </div>
        <div className="edit-weblog-menu__empty-state">
          You don't have access to any weblogs to configure.
        </div>
      </div>
    )
  }

  return (
    <div className="edit-weblog-menu">
      <div className="edit-weblog-menu__header">
        <h1 className="edit-weblog-menu__title">Edit Weblog Menu</h1>
      </div>

      <form onSubmit={handleSubmit}>
        <fieldset className="edit-weblog-menu__fieldset">
          <legend className="edit-weblog-menu__legend">Display</legend>
          <div className="edit-weblog-menu__checkbox-row--last">
            <input
              type="checkbox"
              id="nameifyweblogs"
              checked={nameifyWeblogs}
              onChange={(e) => setNameifyWeblogs(e.target.checked)}
              className="edit-weblog-menu__checkbox"
            />
            <label htmlFor="nameifyweblogs" className="edit-weblog-menu__label">
              Use dynamic names (-ify!)
            </label>
          </div>
        </fieldset>

        <fieldset className="edit-weblog-menu__fieldset">
          <legend className="edit-weblog-menu__legend">Show Items</legend>
          {weblogs.map((weblog, index) => (
            <div
              key={weblog.node_id}
              className={index === weblogs.length - 1 ? 'edit-weblog-menu__checkbox-row--last' : 'edit-weblog-menu__checkbox-row'}
            >
              <input
                type="checkbox"
                id={`show_${weblog.node_id}`}
                checked={weblogVisibility[weblog.node_id] || false}
                onChange={() => handleWeblogToggle(weblog.node_id)}
                className="edit-weblog-menu__checkbox"
              />
              <label htmlFor={`show_${weblog.node_id}`} className="edit-weblog-menu__label">
                {getWeblogTitle(weblog)}
              </label>
            </div>
          ))}
        </fieldset>

        <button
          type="submit"
          className={`edit-weblog-menu__button${saving ? ' edit-weblog-menu__button--disabled' : ''}`}
          disabled={saving}
        >
          {saving ? 'Saving...' : (nameifyWeblogs ? 'Changeify!' : 'Submit')}
        </button>
      </form>

      {message && (
        <div className={`edit-weblog-menu__message edit-weblog-menu__message--${message.type}`}>
          {message.text}
        </div>
      )}
    </div>
  )
}

export default EditWeblogMenu
