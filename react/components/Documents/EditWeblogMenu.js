import React, { useState, useCallback } from 'react'

const styles = {
  container: {
    maxWidth: '600px',
    margin: '0 auto',
    padding: '20px',
  },
  header: {
    marginBottom: '20px',
    borderBottom: '1px solid #ccc',
    paddingBottom: '10px',
  },
  title: {
    margin: 0,
    fontSize: '1.5rem',
  },
  fieldset: {
    marginBottom: '20px',
    padding: '15px',
    border: '1px solid #ddd',
    borderRadius: '8px',
    backgroundColor: '#f8f9fa',
  },
  legend: {
    fontWeight: 'bold',
    padding: '0 10px',
    fontSize: '1.1rem',
  },
  checkboxRow: {
    display: 'flex',
    alignItems: 'center',
    padding: '8px 0',
    borderBottom: '1px solid #eee',
  },
  checkboxRowLast: {
    display: 'flex',
    alignItems: 'center',
    padding: '8px 0',
  },
  checkbox: {
    marginRight: '10px',
    cursor: 'pointer',
  },
  label: {
    cursor: 'pointer',
    flex: 1,
  },
  button: {
    padding: '10px 20px',
    backgroundColor: '#007bff',
    color: 'white',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
    fontSize: '14px',
    marginTop: '10px',
  },
  buttonDisabled: {
    padding: '10px 20px',
    backgroundColor: '#6c757d',
    color: 'white',
    border: 'none',
    borderRadius: '4px',
    cursor: 'not-allowed',
    fontSize: '14px',
    marginTop: '10px',
  },
  message: {
    padding: '10px',
    marginTop: '15px',
    borderRadius: '4px',
  },
  success: {
    backgroundColor: '#d4edda',
    color: '#155724',
    border: '1px solid #c3e6cb',
  },
  error: {
    backgroundColor: '#f8d7da',
    color: '#721c24',
    border: '1px solid #f5c6cb',
  },
  emptyState: {
    padding: '20px',
    textAlign: 'center',
    color: '#666',
    fontStyle: 'italic',
  },
}

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
      <div style={styles.container}>
        <div style={styles.header}>
          <h1 style={styles.title}>Edit Weblog Menu</h1>
        </div>
        <div style={styles.emptyState}>
          You don't have access to any weblogs to configure.
        </div>
      </div>
    )
  }

  return (
    <div style={styles.container}>
      <div style={styles.header}>
        <h1 style={styles.title}>Edit Weblog Menu</h1>
      </div>

      <form onSubmit={handleSubmit}>
        <fieldset style={styles.fieldset}>
          <legend style={styles.legend}>Display</legend>
          <div style={styles.checkboxRowLast}>
            <input
              type="checkbox"
              id="nameifyweblogs"
              checked={nameifyWeblogs}
              onChange={(e) => setNameifyWeblogs(e.target.checked)}
              style={styles.checkbox}
            />
            <label htmlFor="nameifyweblogs" style={styles.label}>
              Use dynamic names (-ify!)
            </label>
          </div>
        </fieldset>

        <fieldset style={styles.fieldset}>
          <legend style={styles.legend}>Show Items</legend>
          {weblogs.map((weblog, index) => (
            <div
              key={weblog.node_id}
              style={index === weblogs.length - 1 ? styles.checkboxRowLast : styles.checkboxRow}
            >
              <input
                type="checkbox"
                id={`show_${weblog.node_id}`}
                checked={weblogVisibility[weblog.node_id] || false}
                onChange={() => handleWeblogToggle(weblog.node_id)}
                style={styles.checkbox}
              />
              <label htmlFor={`show_${weblog.node_id}`} style={styles.label}>
                {getWeblogTitle(weblog)}
              </label>
            </div>
          ))}
        </fieldset>

        <button
          type="submit"
          style={saving ? styles.buttonDisabled : styles.button}
          disabled={saving}
        >
          {saving ? 'Saving...' : (nameifyWeblogs ? 'Changeify!' : 'Submit')}
        </button>
      </form>

      {message && (
        <div style={{ ...styles.message, ...(message.type === 'success' ? styles.success : styles.error) }}>
          {message.text}
        </div>
      )}
    </div>
  )
}

export default EditWeblogMenu
