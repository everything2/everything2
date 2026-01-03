import React, { useState, useCallback, useEffect } from 'react'

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
  intro: {
    fontStyle: 'italic',
    marginBottom: '20px',
    color: '#666',
  },
  form: {
    padding: '20px',
    backgroundColor: '#f8f9fa',
    borderRadius: '8px',
    marginBottom: '20px',
  },
  formGroup: {
    marginBottom: '15px',
  },
  label: {
    display: 'block',
    marginBottom: '5px',
    fontWeight: 'bold',
  },
  input: {
    width: '100%',
    padding: '10px',
    fontSize: '14px',
    border: '1px solid #ccc',
    borderRadius: '4px',
    boxSizing: 'border-box',
  },
  radioGroup: {
    display: 'flex',
    gap: '20px',
    marginTop: '5px',
  },
  radioLabel: {
    display: 'flex',
    alignItems: 'center',
    gap: '5px',
    cursor: 'pointer',
  },
  button: {
    padding: '12px 24px',
    backgroundColor: '#28a745',
    color: 'white',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
    fontSize: '16px',
    fontWeight: 'bold',
  },
  buttonDisabled: {
    padding: '12px 24px',
    backgroundColor: '#6c757d',
    color: 'white',
    border: 'none',
    borderRadius: '4px',
    cursor: 'not-allowed',
    fontSize: '16px',
    fontWeight: 'bold',
  },
  result: {
    padding: '15px',
    marginTop: '20px',
    borderRadius: '8px',
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
  nodeLink: {
    color: '#007bff',
    textDecoration: 'none',
  },
  warning: {
    padding: '15px',
    backgroundColor: '#fff3cd',
    color: '#856404',
    border: '1px solid #ffeeba',
    borderRadius: '8px',
    marginBottom: '20px',
  },
}

const DrNatesSecretLab = ({ data }) => {
  const {
    prefillNodeId = '',
    prefillSource = 'tomb',
    error: pageError,
  } = data || {}

  const [nodeId, setNodeId] = useState(prefillNodeId)
  const [source, setSource] = useState(prefillSource)
  const [processing, setProcessing] = useState(false)
  const [result, setResult] = useState(null)

  // If prefilled, attempt resurrection automatically
  useEffect(() => {
    if (prefillNodeId && !result) {
      handleResurrect()
    }
  }, []) // eslint-disable-line react-hooks/exhaustive-deps

  const handleResurrect = useCallback(async (e) => {
    if (e) e.preventDefault()

    if (!nodeId || !/^\d+$/.test(nodeId)) {
      setResult({
        type: 'error',
        message: 'Please enter a valid node ID',
      })
      return
    }

    setProcessing(true)
    setResult(null)

    try {
      const response = await fetch('/api/resurrect/node', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({
          node_id: parseInt(nodeId, 10),
          source: source,
        }),
      })

      const data = await response.json()

      if (data.success) {
        setResult({
          type: 'success',
          message: data.message,
          nodeId: data.node_id,
          title: data.title,
          e2nodeAttached: data.e2nodeAttached,
        })
        setNodeId('')
      } else {
        setResult({
          type: 'error',
          message: data.error || 'Resurrection failed',
          existingTitle: data.existingTitle,
        })
      }
    } catch (err) {
      setResult({
        type: 'error',
        message: 'Failed to connect to server',
      })
    } finally {
      setProcessing(false)
    }
  }, [nodeId, source])

  if (pageError) {
    return (
      <div style={styles.container}>
        <div style={styles.header}>
          <h1 style={styles.title}>Dr. Nate's Secret Lab</h1>
        </div>
        <div style={{ ...styles.result, ...styles.error }}>
          {pageError}
        </div>
      </div>
    )
  }

  return (
    <div style={styles.container}>
      <div style={styles.header}>
        <h1 style={styles.title}>Dr. Nate's Secret Lab</h1>
      </div>

      <p style={styles.intro}>
        It... it... it... it...
      </p>

      <div style={styles.warning}>
        <strong>Warning:</strong> This tool resurrects deleted nodes from the tomb or node heaven.
        Use with caution. The resurrected node will be restored to its pre-deletion state.
      </div>

      <form style={styles.form} onSubmit={handleResurrect}>
        <div style={styles.formGroup}>
          <label style={styles.label} htmlFor="nodeId">
            Node ID to resurrect:
          </label>
          <input
            type="text"
            id="nodeId"
            value={nodeId}
            onChange={(e) => setNodeId(e.target.value)}
            style={styles.input}
            placeholder="Enter the node_id of the deleted node"
            disabled={processing}
          />
        </div>

        <div style={styles.formGroup}>
          <label style={styles.label}>
            Source:
          </label>
          <div style={styles.radioGroup}>
            <label style={styles.radioLabel}>
              <input
                type="radio"
                name="source"
                value="tomb"
                checked={source === 'tomb'}
                onChange={(e) => setSource(e.target.value)}
                disabled={processing}
              />
              Tomb (recently deleted)
            </label>
            <label style={styles.radioLabel}>
              <input
                type="radio"
                name="source"
                value="heaven"
                checked={source === 'heaven'}
                onChange={(e) => setSource(e.target.value)}
                disabled={processing}
              />
              Heaven (archived)
            </label>
          </div>
        </div>

        <button
          type="submit"
          style={processing ? styles.buttonDisabled : styles.button}
          disabled={processing}
        >
          {processing ? 'Resurrecting...' : 'Resurrect Node'}
        </button>
      </form>

      {result && (
        <div style={{ ...styles.result, ...(result.type === 'success' ? styles.success : styles.error) }}>
          {result.type === 'success' ? (
            <>
              <p><strong>Success!</strong> {result.message}</p>
              <p>
                Resurrected as: <a href={`/node/${result.nodeId}`} style={styles.nodeLink}>
                  {result.title}
                </a>
              </p>
              {result.e2nodeAttached && (
                <p><em>The writeup was re-attached to its e2node.</em></p>
              )}
            </>
          ) : (
            <>
              <p><strong>Error:</strong> {result.message}</p>
              {result.existingTitle && (
                <p>Existing node: <a href={`/title/${encodeURIComponent(result.existingTitle)}`} style={styles.nodeLink}>
                  {result.existingTitle}
                </a></p>
              )}
            </>
          )}
        </div>
      )}
    </div>
  )
}

export default DrNatesSecretLab
