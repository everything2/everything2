import React, { useState } from 'react'
import LinkNode from '../LinkNode'

/**
 * RenunciationChainsaw - Bulk transfer writeup ownership (admin).
 *
 * The transfer and the "generate nodelist" read drive the renunciation API
 * (#4414) instead of a POST form that reparented writeups inside the page
 * controller:
 *   - transfer: POST /api/renunciation/transfer { user_from, user_to, namelist }
 *   - nodelist: POST /api/renunciation/nodes    { user }
 * The result buckets are held in client state; the ?wu_id prefill still arrives
 * as initial pagestate data.
 */
const RenunciationChainsaw = ({ data, e2 }) => {
  const node_id = e2?.node?.node_id ?? window.e2?.node?.node_id
  const { error, prefill_user = '', prefill_node = '' } = data

  const [userFrom, setUserFrom] = useState(prefill_user)
  const [userTo, setUserTo] = useState('')
  const [namelist, setNamelist] = useState(prefill_node)
  const [result, setResult] = useState(null)
  const [listError, setListError] = useState(null)
  const [apiError, setApiError] = useState(null)
  const [busy, setBusy] = useState(false)

  if (error) {
    return <div className="error-message">{error}</div>
  }

  const post = async (route, body) => {
    const res = await fetch(`/api/renunciation/${route}`, {
      method: 'POST',
      credentials: 'same-origin',
      headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      body: JSON.stringify(body),
    })
    return res.ok ? res.json() : null
  }

  const handleGenerate = async (e) => {
    e.preventDefault()
    const u = userFrom.trim()
    if (!u) { setListError('Please enter a username first'); return }
    setBusy(true); setListError(null); setApiError(null)
    try {
      const body = await post('nodes', { user: u })
      if (body && body.success && body.generated_list) {
        setNamelist(body.generated_list.nodes.map((n) => n.title).join('\n'))
      } else {
        setListError((body && body.error) || `No such user: "${u}"`)
      }
    } catch (err) {
      setListError(err.message || 'Failed to generate list')
    } finally { setBusy(false) }
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    setBusy(true); setApiError(null)
    try {
      const body = await post('transfer', {
        user_from: userFrom.trim(), user_to: userTo.trim(), namelist,
      })
      if (body && body.success) setResult(body)
      else setApiError((body && body.error) || 'Transfer failed')
    } catch (err) {
      setApiError(err.message || 'Transfer failed')
    } finally { setBusy(false) }
  }

  // Results view (after a transfer)
  if (result && result.processed) {
    const {
      from_user, to_user,
      reparented = [], nonexistent = [], no_writeup = [], bad_owner = [], bad_type = [],
    } = result
    return (
      <div className="renunciation-chainsaw">
        <dl>
          {reparented.length > 0 && (
            <>
              <dt>
                <strong>
                  {reparented.length} writeups re-ownered from{' '}
                  <LinkNode id={from_user.id} display={from_user.title} /> to{' '}
                  <LinkNode id={to_user.id} display={to_user.title} />:
                </strong>
              </dt>
              {reparented.map((node, idx) => (
                <dd key={idx}><LinkNode id={node.node_id} display={node.title} /></dd>
              ))}
            </>
          )}

          {nonexistent.length > 0 && (
            <span className="renunciation-chainsaw__error">
              <dt>&nbsp;</dt>
              <dt>
                <strong>Nonexistent nodes:</strong> (if you provided writeup titles,
                they may differ from their parent node titles due to the parent nodes
                having been renamed)
              </dt>
              {nonexistent.map((node, idx) => (<dd key={idx}>{node.title}</dd>))}
            </span>
          )}

          {bad_owner.length > 0 && (
            <span className="renunciation-chainsaw__error">
              <dt>&nbsp;</dt>
              <dt><strong>Wrong <code>author_user</code> (SQL problem; talk to nate):</strong></dt>
              {bad_owner.map((node, idx) => (
                <dd key={idx}><LinkNode id={node.node_id} display={node.title} /></dd>
              ))}
            </span>
          )}

          {bad_type.length > 0 && (
            <span className="renunciation-chainsaw__error">
              <dt>&nbsp;</dt>
              <dt><strong>Wrong <code>type_nodetype</code> (SQL problem; talk to nate):</strong></dt>
              {bad_type.map((node, idx) => (
                <dd key={idx}><LinkNode id={node.node_id} display={node.title} /></dd>
              ))}
            </span>
          )}

          {no_writeup.length > 0 && (
            <span className="renunciation-chainsaw__error">
              <dt>&nbsp;</dt>
              <dt>
                <strong>
                  <LinkNode id={from_user.id} display={from_user.title} /> has nothing here:
                </strong>
              </dt>
              {no_writeup.map((node, idx) => (
                <dd key={idx}><LinkNode id={node.node_id} display={node.title} /></dd>
              ))}
            </span>
          )}

          <p className="renunciation-chainsaw__back-link">
            [ <button type="button" className="renunciation-chainsaw__back-btn" onClick={() => setResult(null)}>back</button> ]
          </p>
        </dl>
      </div>
    )
  }

  // Form view
  return (
    <div className="renunciation-chainsaw">
      {apiError && <p className="renunciation-chainsaw__error">{apiError}</p>}
      <form onSubmit={handleSubmit}>
        <p>
          Change ownership of writeups from user<br />
          <input
            type="text"
            value={userFrom}
            onChange={(e) => setUserFrom(e.target.value)}
            className="renunciation-chainsaw__input"
            disabled={busy}
          />
          {' '}
          <button
            type="button"
            onClick={handleGenerate}
            className="renunciation-chainsaw__generate-btn"
            disabled={busy}
          >
            Generate nodelist
          </button>
        </p>

        {listError && <p className="renunciation-chainsaw__list-error">{listError}</p>}

        <p>
          to user<br />
          <input
            type="text"
            value={userTo}
            onChange={(e) => setUserTo(e.target.value)}
            className="renunciation-chainsaw__input"
            disabled={busy}
          />
        </p>

        <p>The writeups in question:</p>
        <textarea
          value={namelist}
          onChange={(e) => setNamelist(e.target.value)}
          rows={20}
          cols={50}
          disabled={busy}
        />

        <p>
          <button type="submit" disabled={busy}>{busy ? 'Working…' : 'Do It'}</button>
        </p>
      </form>
    </div>
  )
}

export default RenunciationChainsaw
