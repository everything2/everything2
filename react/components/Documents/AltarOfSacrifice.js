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
      <div style={styles.container}>
        <h2 style={styles.title}>Altar of Sacrifice</h2>
        <div style={styles.errorBox}>
          <p>This tool is for editors only.</p>
        </div>
      </div>
    )
  }

  return (
    <div style={styles.container}>
      <h2 style={styles.title}>Altar of Sacrifice</h2>

      <p style={styles.intro}>
        Welcome to the mountaintop. Don&apos;t mind the blood.
      </p>

      <p style={styles.note}>
        <strong>N.B.:</strong> This tool <em>will</em> remove the writeups you select.
      </p>

      <div style={styles.instructions}>
        <h3 style={styles.instructionsTitle}>Instructions</h3>
        <ol style={styles.instructionsList}>
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
  <form method="get" style={styles.form}>
    <input type="hidden" name="node_id" value={nodeId} />
    <fieldset style={styles.fieldset}>
      <legend style={styles.legend}>Step 1: the victim</legend>

      {error && (
        <p style={styles.error}>{error}</p>
      )}

      <label style={styles.label}>
        User name:{' '}
        <input
          type="text"
          name="author"
          style={styles.input}
          autoFocus
        />
      </label>
      {' '}
      <button type="submit" style={styles.button}>Submit</button>
    </fieldset>
  </form>
)

const StepEmpty = ({ authorId, authorName }) => (
  <fieldset style={styles.fieldset}>
    <legend style={styles.legend}>Nothing to do</legend>
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
    <form method="post" style={styles.form} ref={formRef}>
      <input type="hidden" name="node_id" value={nodeId} />
      <input type="hidden" name="author" value={authorName} />
      <input type="hidden" name="op" value="remove" />

      <fieldset style={styles.fieldset}>
        <legend style={styles.legend}>Step 2: show mercy (or not)</legend>

        <h3 style={styles.userTitle}>
          <LinkNode id={authorId} display={authorName} />&apos;s writeups{pageDisplay}
        </h3>

        <p style={styles.summary}>
          Showing {writeups.length} of {total} total writeups.
          {' '}{selectedForRemoval.size} selected for removal.
        </p>

        <div style={styles.actions}>
          <button type="button" onClick={selectAll} style={styles.smallButton}>
            Select All
          </button>
          {' '}
          <button type="button" onClick={selectNone} style={styles.smallButton}>
            Select None
          </button>
        </div>

        <table style={styles.table}>
          <thead>
            <tr>
              <th style={styles.thAxe}>axe</th>
              <th style={styles.thId}>id</th>
              <th style={styles.th}>title</th>
            </tr>
          </thead>
          <tbody>
            {writeups.map((wu, idx) => (
              <tr key={wu.node_id} style={idx % 2 === 1 ? styles.oddRow : undefined}>
                <td style={styles.tdAxe}>
                  <input
                    type="checkbox"
                    name={`removenode${wu.node_id}`}
                    value="1"
                    checked={selectedForRemoval.has(wu.node_id)}
                    onChange={() => toggleWriteup(wu.node_id)}
                  />
                </td>
                <td style={styles.tdId}>{wu.node_id}</td>
                <td style={styles.td}>
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
          <p style={styles.removeAllOption}>
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

        <p style={styles.reasonField}>
          <label>
            Reason for removal (optional):{' '}
            <input
              type="text"
              name="removereason"
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              style={styles.reasonInput}
              size="50"
            />
          </label>
        </p>

        <p>
          <button
            type="button"
            onClick={handleSubmitClick}
            style={styles.dangerButton}
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
    <div style={styles.pagination}>
      {page > 1 && (
        <a
          href={`?author=${encodeURIComponent(authorName)}&page=${page - 1}`}
          style={styles.link}
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
              style={styles.link}
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
          style={styles.link}
        >
          Next &raquo;
        </a>
      )}
    </div>
  )
}

const styles = {
  container: {
    padding: '10px',
    fontSize: '13px',
    lineHeight: '1.5',
    color: '#111'
  },
  title: {
    fontSize: '18px',
    fontWeight: 'bold',
    margin: '0 0 10px 0',
    color: '#38495e'
  },
  intro: {
    marginBottom: '10px'
  },
  note: {
    marginBottom: '15px',
    color: '#c62828'
  },
  instructions: {
    backgroundColor: '#f8f9f9',
    border: '1px solid #d3d3d3',
    borderRadius: '4px',
    padding: '15px',
    marginBottom: '20px'
  },
  instructionsTitle: {
    margin: '0 0 10px 0',
    fontSize: '14px'
  },
  instructionsList: {
    margin: '0',
    paddingLeft: '25px'
  },
  form: {
    marginTop: '15px'
  },
  fieldset: {
    border: '1px solid #d3d3d3',
    borderRadius: '4px',
    padding: '15px'
  },
  legend: {
    fontWeight: 'bold',
    padding: '0 10px'
  },
  label: {
    marginRight: '10px'
  },
  input: {
    padding: '6px 10px',
    fontSize: '13px',
    border: '1px solid #d3d3d3',
    borderRadius: '3px',
    width: '200px'
  },
  button: {
    padding: '8px 20px',
    backgroundColor: '#38495e',
    color: '#ffffff',
    border: 'none',
    borderRadius: '3px',
    cursor: 'pointer',
    fontSize: '13px'
  },
  smallButton: {
    padding: '4px 12px',
    backgroundColor: '#f0f0f0',
    color: '#333',
    border: '1px solid #d3d3d3',
    borderRadius: '3px',
    cursor: 'pointer',
    fontSize: '12px'
  },
  dangerButton: {
    padding: '10px 25px',
    backgroundColor: '#c62828',
    color: '#ffffff',
    border: 'none',
    borderRadius: '3px',
    cursor: 'pointer',
    fontSize: '14px',
    fontWeight: 'bold'
  },
  errorBox: {
    backgroundColor: '#ffebee',
    border: '1px solid #f44336',
    borderRadius: '4px',
    padding: '15px',
    color: '#c62828'
  },
  error: {
    color: '#c62828',
    marginBottom: '10px'
  },
  userTitle: {
    fontSize: '16px',
    margin: '0 0 10px 0'
  },
  summary: {
    color: '#507898',
    marginBottom: '10px'
  },
  actions: {
    marginBottom: '15px'
  },
  table: {
    width: '100%',
    borderCollapse: 'collapse',
    marginBottom: '15px'
  },
  th: {
    backgroundColor: '#38495e',
    color: '#ffffff',
    padding: '8px 10px',
    textAlign: 'left'
  },
  thAxe: {
    backgroundColor: '#38495e',
    color: '#ffffff',
    padding: '8px 10px',
    textAlign: 'center',
    width: '50px'
  },
  thId: {
    backgroundColor: '#38495e',
    color: '#ffffff',
    padding: '8px 10px',
    textAlign: 'center',
    width: '80px'
  },
  td: {
    padding: '6px 10px',
    borderBottom: '1px solid #e0e0e0'
  },
  tdAxe: {
    padding: '6px 10px',
    borderBottom: '1px solid #e0e0e0',
    textAlign: 'center'
  },
  tdId: {
    padding: '6px 10px',
    borderBottom: '1px solid #e0e0e0',
    textAlign: 'center',
    fontFamily: 'monospace',
    fontSize: '12px',
    color: '#507898'
  },
  oddRow: {
    backgroundColor: '#f8f9f9'
  },
  pagination: {
    textAlign: 'center',
    marginBottom: '15px'
  },
  link: {
    color: '#4060b0',
    textDecoration: 'none'
  },
  removeAllOption: {
    backgroundColor: '#fff3e0',
    border: '1px solid #ff9800',
    borderRadius: '4px',
    padding: '10px',
    marginBottom: '15px'
  },
  reasonField: {
    marginBottom: '15px'
  },
  reasonInput: {
    padding: '6px 10px',
    fontSize: '13px',
    border: '1px solid #d3d3d3',
    borderRadius: '3px'
  }
}

export default AltarOfSacrifice
