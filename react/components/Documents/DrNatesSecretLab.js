import React, { useState, useCallback, useEffect } from 'react'

/**
 * DrNatesSecretLab - Tool for resurrecting deleted nodes
 * Styles in CSS: .dr-nates-lab__*
 *
 * Allows admins to resurrect nodes from tomb or heaven.
 */
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
      <div className="dr-nates-lab">
        <div className="dr-nates-lab__header">
          <h1 className="dr-nates-lab__title">Dr. Nate's Secret Lab</h1>
        </div>
        <div className="dr-nates-lab__result dr-nates-lab__result--error">
          {pageError}
        </div>
      </div>
    )
  }

  return (
    <div className="dr-nates-lab">
      <div className="dr-nates-lab__header">
        <h1 className="dr-nates-lab__title">Dr. Nate's Secret Lab</h1>
      </div>

      <p className="dr-nates-lab__intro">
        It... it... it... it...
      </p>

      <div className="dr-nates-lab__warning">
        <strong>Warning:</strong> This tool resurrects deleted nodes from the tomb or node heaven.
        Use with caution. The resurrected node will be restored to its pre-deletion state.
      </div>

      <form className="dr-nates-lab__form" onSubmit={handleResurrect}>
        <div className="dr-nates-lab__form-group">
          <label className="dr-nates-lab__label" htmlFor="nodeId">
            Node ID to resurrect:
          </label>
          <input
            type="text"
            id="nodeId"
            value={nodeId}
            onChange={(e) => setNodeId(e.target.value)}
            className="dr-nates-lab__input"
            placeholder="Enter the node_id of the deleted node"
            disabled={processing}
          />
        </div>

        <div className="dr-nates-lab__form-group">
          <label className="dr-nates-lab__label">
            Source:
          </label>
          <div className="dr-nates-lab__radio-group">
            <label className="dr-nates-lab__radio-label">
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
            <label className="dr-nates-lab__radio-label">
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
          className={processing ? 'dr-nates-lab__button--disabled' : 'dr-nates-lab__button'}
          disabled={processing}
        >
          {processing ? 'Resurrecting...' : 'Resurrect Node'}
        </button>
      </form>

      {result && (
        <div className={`dr-nates-lab__result ${result.type === 'success' ? 'dr-nates-lab__result--success' : 'dr-nates-lab__result--error'}`}>
          {result.type === 'success' ? (
            <>
              <p><strong>Success!</strong> {result.message}</p>
              <p>
                Resurrected as: <a href={`/node/${result.nodeId}`} className="dr-nates-lab__node-link">
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
                <p>Existing node: <a href={`/title/${encodeURIComponent(result.existingTitle)}`} className="dr-nates-lab__node-link">
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
