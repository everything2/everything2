import React, { useState } from 'react'
import LinkNode from '../LinkNode'
import { formatDateTime } from '../../utils/dateFormat'

/**
 * Clientdev Home - E2 Client Development homepage
 * Styles in CSS: .clientdev-home__*
 *
 * Shows registered E2 clients, registration form, and clientdev weblog.
 */
const ClientdevHome = ({ data, e2 }) => {
  const {
    clients = [],
    can_create = false,
    nwing = {},
    show_weblog = false,
    weblog = {}
  } = data

  const {
    entries: initialEntries = [],
    weblog_id = 0,
    can_remove = false,
    has_older = false,
    has_newer = false,
    next_older = 0,
    next_newer = 0
  } = weblog

  const [entries, setEntries] = useState(initialEntries)
  const [confirmModal, setConfirmModal] = useState(null)
  const [removing, setRemoving] = useState(false)
  const [clientName, setClientName] = useState('')
  const [createError, setCreateError] = useState('')

  const currentNodeId = e2?.node_id || data.node_id

  // Create the e2client via the generic node API (was op=new). #4340 Phase 2.
  const handleSubmit = async (e) => {
    e.preventDefault()
    setCreateError('')
    const title = clientName.trim()
    if (!title) return
    try {
      const res = await fetch('/api/node/create', {
        method: 'POST',
        credentials: 'same-origin',
        headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
        body: JSON.stringify({ type: 'e2client', title }),
      })
      const result = res.ok ? await res.json() : null
      if (result && result.success && result.node_id) {
        window.location.href = `/node/${result.node_id}`
        return
      }
      setCreateError((result && result.error) || 'Could not register the client')
    } catch (err) {
      setCreateError('Network error: ' + err.message)
    }
  }

  const handleRemoveClick = (entry) => {
    setConfirmModal(entry)
  }

  const handleConfirmRemove = async () => {
    if (!confirmModal || removing) return

    setRemoving(true)
    try {
      const response = await fetch(`/api/weblog/${weblog_id}/${confirmModal.node_id}`, {
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json'
        }
      })

      const result = await response.json()

      if (result.success) {
        setEntries(entries.filter(e => e.node_id !== confirmModal.node_id))
        setConfirmModal(null)
      } else {
        alert('Failed to remove entry: ' + (result.error || 'Unknown error'))
      }
    } catch (err) {
      alert('Failed to remove entry: ' + err.message)
    } finally {
      setRemoving(false)
    }
  }

  const handleCancelRemove = () => {
    setConfirmModal(null)
  }

  return (
    <div className="clientdev-home">
      <h2 className="clientdev-home__heading">Registered Clients</h2>

      <p>
        (See{' '}
        <LinkNode
          nodeId={0}
          title="Registering a client"
          params={{ node: 'clientdev', lastnode_id: 0 }}
        />{' '}
        for more information as to what this is about)
        <br />
      </p>

      <table className="clientdev-home__table">
        <thead>
          <tr className="clientdev-home__header-row">
            <th className="clientdev-home__th">title</th>
            <th className="clientdev-home__th">version</th>
          </tr>
        </thead>
        <tbody>
          {clients.length === 0 ? (
            <tr>
              <td colSpan="2" className="clientdev-home__empty-state">
                No registered clients yet.
              </td>
            </tr>
          ) : (
            clients.map((client) => (
              <tr key={client.node_id} className="clientdev-home__row">
                <td className="clientdev-home__td">
                  <LinkNode nodeId={client.node_id} title={client.title} />
                </td>
                <td className="clientdev-home__td">{client.version}</td>
              </tr>
            ))
          )}
        </tbody>
      </table>

      {Boolean(can_create) && (
        <div className="clientdev-home__create-form">
          <h2 className="clientdev-home__subheading">Register your client:</h2>
          <form onSubmit={handleSubmit} method="post">
            <input
              type="text"
              name="node"
              size="25"
              placeholder="Client name..."
              className="clientdev-home__input"
              value={clientName}
              onChange={(e) => setClientName(e.target.value)}
            />
            <br />
            {createError && <p className="clientdev-home__error">{createError}</p>}
            <input
              type="submit"
              value="Register Client"
              className="clientdev-home__submit-button"
            />
          </form>
        </div>
      )}

      <div className="clientdev-home__section">
        <p>Things to (eventually) come:</p>
        <ol>
          <li>make debates work for general groups</li>
          <li>
            list of people, their programming language, the platform, and the
            project
          </li>
        </ol>
      </div>

      {Boolean(nwing.node_id) && (
        <p>
          <LinkNode
            nodeId={nwing.node_id}
            title="N-Wing Group Messages"
            params={{ displaytype: 'group' }}
          />
        </p>
      )}

      <hr className="clientdev-home__hr" />

      {Boolean(show_weblog) && entries.length > 0 && (
        <div className="clientdev-home__weblog-section">
          <h2 className="clientdev-home__subheading">Clientdev Weblog</h2>
          <div className="clientdev-home__weblog">
            {entries.map((entry, index) => (
              <div key={entry.node_id || index} className="clientdev-home__item">
                <div className="clientdev-home__header">
                  <div className="clientdev-home__header-top">
                    <a
                      href={`/node/document/${encodeURIComponent(entry.title)}`}
                      className="clientdev-home__title"
                    >
                      {entry.title}
                    </a>
                    {Boolean(can_remove) && (
                      <button
                        onClick={() => handleRemoveClick(entry)}
                        className="clientdev-home__remove-button"
                        title="Remove from weblog"
                      >
                        remove
                      </button>
                    )}
                  </div>
                  <cite className="clientdev-home__byline">
                    by{' '}
                    <a
                      href={`/user/${encodeURIComponent(entry.author)}`}
                      className="clientdev-home__author-link"
                    >
                      {entry.author}
                    </a>
                  </cite>
                  <span className="clientdev-home__date">
                    {formatDate(entry.linkedtime)}
                  </span>
                </div>
                <div
                  className="clientdev-home__content"
                  dangerouslySetInnerHTML={{ __html: entry.content }}
                />
              </div>
            ))}
          </div>

          {Boolean(has_newer || has_older) && (
            <div className="clientdev-home__more-link">
              {Boolean(has_newer) && (
                <a
                  href={`/node/${currentNodeId}?nextweblog=${next_newer}`}
                  className="clientdev-home__nav-link"
                >
                  &larr; newer
                </a>
              )}
              {Boolean(has_newer && has_older) && <span className="clientdev-home__separator"> | </span>}
              {Boolean(has_older) && (
                <a
                  href={`/node/${currentNodeId}?nextweblog=${next_older}`}
                  className="clientdev-home__nav-link"
                >
                  older &rarr;
                </a>
              )}
            </div>
          )}
        </div>
      )}

      {/* Confirmation Modal */}
      {confirmModal && (
        <div className="clientdev-home__modal-overlay" onClick={handleCancelRemove}>
          <div className="clientdev-home__modal" onClick={e => e.stopPropagation()}>
            <h3 className="clientdev-home__modal-title">Remove Entry</h3>
            <p className="clientdev-home__modal-text">
              Are you sure you want to remove &ldquo;{confirmModal.title}&rdquo; from this weblog?
            </p>
            <p className="clientdev-home__modal-note">
              This will not delete the document, just remove it from the weblog.
            </p>
            <div className="clientdev-home__modal-buttons">
              <button
                onClick={handleCancelRemove}
                className="clientdev-home__cancel-button"
                disabled={removing}
              >
                Cancel
              </button>
              <button
                onClick={handleConfirmRemove}
                className="clientdev-home__confirm-button"
                disabled={removing}
              >
                {removing ? 'Removing...' : 'Remove'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

/**
 * Format a MySQL datetime string for display.
 * Verbose dev-tool layout: "Mon Dec 06 2025 00:22:26".
 */
function formatDate(dateStr) {
  return formatDateTime(dateStr, {
    weekday: 'short',
    month: 'short',
    day: '2-digit',
    year: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
    second: '2-digit',
    hour12: false,
  })?.replace(',', '') ?? (dateStr ?? '')
}

export default ClientdevHome
