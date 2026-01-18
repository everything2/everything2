import React, { useState, useRef } from 'react'
import LinkNode from '../LinkNode'
import ConfirmActionModal from '../ConfirmActionModal'

/**
 * AltarOfSacrifice - Admin tool to remove writeups from a user.
 *
 * Workflow:
 * 1. Enter a username
 * 2. View their writeups with checkboxes (checked = to be removed)
 * 3. Submit to remove checked writeups using the remove opcode
 *
 * Editor-only tool. Uses existing remove opcode for actual deletion.
 */
const AltarOfSacrifice = ({ data }) => {
  const {
    access_denied,
    step,
    error,
    author_id,
    author_name,
    writeups,
    total,
    page,
    per_page,
    total_pages
  } = data

  // Get current page node_id from global state instead of contentData
  const nodeId = window.e2?.node_id

  const [reason, setReason] = useState('')

  if (access_denied) {
    return (
      <div className="altar">
        <h2 className="altar__title">Altar of Sacrifice</h2>
        <div className="altar__error-box">
          <p>This tool is for editors only.</p>
        </div>
      </div>
    )
  }

  return (
    <div className="altar">
      <h2 className="altar__title">Altar of Sacrifice</h2>

      <p className="altar__intro">
        Welcome to the mountaintop. Don&apos;t mind the blood.
      </p>

      <p className="altar__note">
        <strong>N.B.:</strong> This tool <em>will</em> remove the writeups you select.
      </p>

      <div className="altar__instructions">
        <h3 className="altar__instructions-title">Instructions</h3>
        <ol className="altar__instructions-list">
          <li>Enter a user&apos;s name in the box. Submit.</li>
          <li>Choose which writeups to spare (if any) from the list provided, or choose to remove all writeups at once.</li>
          <li>Confirm that you really want to do this.</li>
          <li>Repeat as necessary.</li>
          <li>Shed a tear, keep a minute&apos;s silence, then hold up the bloody heart to the crowd.</li>
        </ol>
      </div>

      {step === 'input' && (
        <StepInput nodeId={nodeId} error={error} />
      )}

      {step === 'empty' && (
        <StepEmpty authorId={author_id} authorName={author_name} />
      )}

      {step === 'select' && (
        <StepSelect
          nodeId={nodeId}
          authorId={author_id}
          authorName={author_name}
          writeups={writeups}
          total={total}
          page={page}
          perPage={per_page}
          totalPages={total_pages}
          reason={reason}
          setReason={setReason}
        />
      )}
    </div>
  )
}

const StepInput = ({ nodeId, error }) => (
  <form method="get" className="altar__form">
    <input type="hidden" name="node_id" value={nodeId} />
    <fieldset className="altar__fieldset">
      <legend className="altar__legend">Step 1: the victim</legend>

      {error && (
        <p className="altar__error">{error}</p>
      )}

      <label className="altar__label">
        User name:{' '}
        <input
          type="text"
          name="author"
          className="altar__input"
          autoFocus
        />
      </label>
      {' '}
      <button type="submit" className="altar__btn">Submit</button>
    </fieldset>
  </form>
)

const StepEmpty = ({ authorId, authorName }) => (
  <fieldset className="altar__fieldset">
    <legend className="altar__legend">Nothing to do</legend>
    <p>
      <LinkNode id={authorId} display={authorName} /> has no writeups.
    </p>
  </fieldset>
)

const StepSelect = ({
  nodeId,
  authorId,
  authorName,
  writeups,
  total,
  page,
  perPage,
  totalPages,
  reason,
  setReason
}) => {
  // Track which writeups to remove (checked = remove)
  const [selectedForRemoval, setSelectedForRemoval] = useState(
    () => new Set(writeups.map(w => w.node_id))
  )

  // Confirmation modal state
  const [showConfirmModal, setShowConfirmModal] = useState(false)
  const [isSubmitting, setIsSubmitting] = useState(false)
  const formRef = useRef(null)

  const toggleWriteup = (nodeId) => {
    setSelectedForRemoval(prev => {
      const next = new Set(prev)
      if (next.has(nodeId)) {
        next.delete(nodeId)
      } else {
        next.add(nodeId)
      }
      return next
    })
  }

  const selectAll = () => {
    setSelectedForRemoval(new Set(writeups.map(w => w.node_id)))
  }

  const selectNone = () => {
    setSelectedForRemoval(new Set())
  }

  const handleSubmitClick = (e) => {
    e.preventDefault()
    if (selectedForRemoval.size === 0) {
      return // Nothing to remove
    }
    setShowConfirmModal(true)
  }

  const handleConfirmRemoval = () => {
    setIsSubmitting(true)
    // Submit the form with op=remove instead of confirmop=remove
    if (formRef.current) {
      formRef.current.submit()
    }
  }

  const pageDisplay = totalPages > 1 ? `: page ${page}` : ''

  return (
    <form method="post" className="altar__form" ref={formRef}>
      <input type="hidden" name="node_id" value={nodeId} />
      <input type="hidden" name="author" value={authorName} />
      <input type="hidden" name="op" value="remove" />

      <fieldset className="altar__fieldset">
        <legend className="altar__legend">Step 2: show mercy (or not)</legend>

        <h3 className="altar__user-title">
          <LinkNode id={authorId} display={authorName} />&apos;s writeups{pageDisplay}
        </h3>

        <p className="altar__summary">
          Showing {writeups.length} of {total} total writeups.
          {' '}{selectedForRemoval.size} selected for removal.
        </p>

        <div className="altar__actions">
          <button type="button" onClick={selectAll} className="altar__btn--small">
            Select All
          </button>
          {' '}
          <button type="button" onClick={selectNone} className="altar__btn--small">
            Select None
          </button>
        </div>

        <table className="altar__table">
          <thead>
            <tr>
              <th className="altar__th--axe">axe</th>
              <th className="altar__th--id">id</th>
              <th className="altar__th">title</th>
            </tr>
          </thead>
          <tbody>
            {writeups.map((wu, idx) => (
              <tr key={wu.node_id} className={idx % 2 === 1 ? 'altar__row--odd' : undefined}>
                <td className="altar__td--axe">
                  <input
                    type="checkbox"
                    name={`removenode${wu.node_id}`}
                    value="1"
                    checked={selectedForRemoval.has(wu.node_id)}
                    onChange={() => toggleWriteup(wu.node_id)}
                  />
                </td>
                <td className="altar__td--id">{wu.node_id}</td>
                <td className="altar__td">
                  <LinkNode id={wu.node_id} display={wu.title} />
                </td>
              </tr>
            ))}
          </tbody>
        </table>

        {/* Pagination */}
        {totalPages > 1 && (
          <Pagination
            authorName={authorName}
            page={page}
            totalPages={totalPages}
          />
        )}

        {/* Remove all option when paginated */}
        {totalPages > 1 && (
          <p className="altar__remove-all-option">
            <label>
              <input
                type="checkbox"
                name="removeauthor"
                value="1"
              />
              {' '}Remove <strong>all</strong> of {authorName}&apos;s writeups
            </label>
          </p>
        )}

        <p className="altar__reason-field">
          <label>
            Reason for removal (optional):{' '}
            <input
              type="text"
              name="removereason"
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              className="altar__reason-input"
              size="50"
            />
          </label>
        </p>

        <p>
          <button
            type="button"
            onClick={handleSubmitClick}
            className="altar__btn--danger"
            title="Remove these writeups"
            disabled={selectedForRemoval.size === 0}
          >
            Let the axe fall
          </button>
        </p>
      </fieldset>

      {/* Confirmation modal */}
      <ConfirmActionModal
        isOpen={showConfirmModal}
        onClose={() => setShowConfirmModal(false)}
        onConfirm={handleConfirmRemoval}
        title="Confirm Removal"
        message={`Do you really want to return ${selectedForRemoval.size} writeup${selectedForRemoval.size !== 1 ? 's' : ''} to draft status? This will remove them from public view.`}
        confirmLabel="Let the axe fall"
        confirmStyle="danger"
        isSubmitting={isSubmitting}
      />
    </form>
  )
}

const Pagination = ({ authorName, page, totalPages }) => {
  const pages = []
  for (let i = 1; i <= totalPages; i++) {
    pages.push(i)
  }

  return (
    <div className="altar__pagination">
      {page > 1 && (
        <a
          href={`?author=${encodeURIComponent(authorName)}&page=${page - 1}`}
          className="altar__link"
        >
          &laquo; Previous
        </a>
      )}
      {pages.map(p => (
        <span key={p}>
          {' '}
          {p === page ? (
            <strong>{p}</strong>
          ) : (
            <a
              href={`?author=${encodeURIComponent(authorName)}&page=${p}`}
              className="altar__link"
            >
              {p}
            </a>
          )}
          {' '}
        </span>
      ))}
      {page < totalPages && (
        <a
          href={`?author=${encodeURIComponent(authorName)}&page=${page + 1}`}
          className="altar__link"
        >
          Next &raquo;
        </a>
      )}
    </div>
  )
}

export default AltarOfSacrifice
