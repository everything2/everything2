import React, { useState } from 'react'
import LinkNode from '../LinkNode'

/**
 * KlaprothVanLines - Bulk reparenting of writeups for a single user.
 * Admin-only tool that allows reparenting multiple writeups at once.
 *
 * Workflow:
 * 1. Enter username and lists of writeup IDs + destination e2node names
 * 2. Validate writeups belong to user and destinations exist
 * 3. Preview changes before committing
 * 4. Execute reparenting using the writeup_reparent API
 */
const KlaprothVanLines = ({ data }) => {
  const { access_denied } = data

  // Form state
  const [username, setUsername] = useState('')
  const [writeupIds, setWriteupIds] = useState('')
  const [destinations, setDestinations] = useState('')

  // Validation state
  const [validatedData, setValidatedData] = useState(null)
  const [validationErrors, setValidationErrors] = useState([])

  // Execution state
  const [isLoading, setIsLoading] = useState(false)
  const [results, setResults] = useState(null)
  const [step, setStep] = useState('input') // 'input', 'preview', 'complete'

  if (access_denied) {
    return (
      <div style={styles.container}>
        <h2 style={styles.title}>Klaproth Van Lines</h2>
        <p style={styles.welcome}>
          Welcome to Klaproth Van Lines. This utility will reparent writeups for a single user in
          bulk.
        </p>
        <div style={styles.errorBox}>
          <p>[Klaproth] has no business with you ... just now.</p>
        </div>
      </div>
    )
  }

  const handleValidate = async (e) => {
    e.preventDefault()
    setIsLoading(true)
    setValidationErrors([])
    setValidatedData(null)

    try {
      // Parse inputs
      const idList = writeupIds
        .split('\n')
        .map((id) => id.trim())
        .filter((id) => id && /^\d+$/.test(id))
      const destList = destinations
        .split('\n')
        .map((d) => d.trim())
        .filter((d) => d)

      const errors = []

      // Check counts match
      if (idList.length !== destList.length) {
        errors.push(
          `Mismatched lists: ${idList.length} writeup ID${idList.length !== 1 ? 's' : ''}, ${destList.length} destination${destList.length !== 1 ? 's' : ''}`
        )
      }

      if (idList.length === 0) {
        errors.push('No valid writeup IDs provided')
      }

      if (!username.trim()) {
        errors.push('Username is required')
      }

      if (errors.length > 0) {
        setValidationErrors(errors)
        setIsLoading(false)
        return
      }

      // Fetch user info
      const userResponse = await fetch(`/api/user?username=${encodeURIComponent(username.trim())}`)
      const userData = await userResponse.json()

      if (!userData.success || !userData.data) {
        errors.push(`User "${username}" not found`)
        setValidationErrors(errors)
        setIsLoading(false)
        return
      }

      const targetUser = userData.data

      // Validate each writeup and destination
      const validatedWriteups = []
      const validatedDestinations = []

      for (let i = 0; i < idList.length; i++) {
        const writeupId = idList[i]
        const destName = destList[i] || ''

        // Fetch writeup info using the reparent API
        const writeupResponse = await fetch(
          `/api/writeup_reparent?old_writeup_id=${encodeURIComponent(writeupId)}`
        )
        const writeupData = await writeupResponse.json()

        if (!writeupData.success || !writeupData.data.old_writeup) {
          errors.push(`Writeup ID ${writeupId}: not found or invalid`)
          continue
        }

        const writeup = writeupData.data.old_writeup

        // Check author matches
        if (writeup.author_id !== targetUser.node_id) {
          errors.push(
            `Writeup "${writeup.title}" (ID ${writeupId}): not by ${targetUser.title} (author: ${writeup.author_title})`
          )
          continue
        }

        // Fetch destination e2node
        const destResponse = await fetch(
          `/api/writeup_reparent?new_e2node_id=${encodeURIComponent(destName)}`
        )
        const destData = await destResponse.json()

        if (!destData.success || !destData.data.new_e2node) {
          errors.push(`Destination "${destName}": not a valid e2node`)
          continue
        }

        validatedWriteups.push({
          ...writeup,
          oldParent: writeupData.data.old_e2node
        })
        validatedDestinations.push(destData.data.new_e2node)
      }

      if (errors.length > 0) {
        setValidationErrors(errors)
      }

      if (validatedWriteups.length > 0) {
        setValidatedData({
          user: targetUser,
          writeups: validatedWriteups,
          destinations: validatedDestinations
        })
        setStep('preview')
      }
    } catch (err) {
      setValidationErrors([`Network error: ${err.message}`])
    } finally {
      setIsLoading(false)
    }
  }

  const handleExecute = async () => {
    if (!validatedData) return

    setIsLoading(true)
    setResults(null)

    try {
      const allResults = []

      // Execute reparenting for each writeup individually to different destinations
      for (let i = 0; i < validatedData.writeups.length; i++) {
        const writeup = validatedData.writeups[i]
        const dest = validatedData.destinations[i]

        const response = await fetch('/api/writeup_reparent/reparent', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            new_e2node_id: dest.node_id,
            writeup_ids: [writeup.node_id]
          })
        })

        const result = await response.json()

        if (result.success && result.results && result.results[0]) {
          allResults.push({
            ...result.results[0],
            destTitle: dest.title
          })
        } else {
          allResults.push({
            success: false,
            writeup_id: writeup.node_id,
            old_title: writeup.title,
            error: result.error || 'Unknown error'
          })
        }
      }

      setResults(allResults)
      setStep('complete')
    } catch (err) {
      setValidationErrors([`Network error: ${err.message}`])
    } finally {
      setIsLoading(false)
    }
  }

  const handleReset = () => {
    setStep('input')
    setValidatedData(null)
    setValidationErrors([])
    setResults(null)
  }

  return (
    <div style={styles.container}>
      <h2 style={styles.title}>Klaproth Van Lines</h2>
      <p style={styles.welcome}>
        Welcome to Klaproth Van Lines. This utility will reparent writeups for a single user in
        bulk.
      </p>

      {/* Validation errors */}
      {validationErrors.length > 0 && (
        <div style={styles.errorBox}>
          <strong>Errors:</strong>
          <ul style={styles.errorList}>
            {validationErrors.map((err, idx) => (
              <li key={idx}>{err}</li>
            ))}
          </ul>
        </div>
      )}

      {/* Step 1: Input form */}
      {step === 'input' && (
        <form onSubmit={handleValidate}>
          <table style={styles.table}>
            <tbody>
              <tr>
                <td colSpan={2} style={styles.td}>
                  <label>
                    <strong>Username:</strong>{' '}
                    <input
                      type="text"
                      value={username}
                      onChange={(e) => setUsername(e.target.value)}
                      style={styles.input}
                      placeholder="Enter username"
                    />
                  </label>
                </td>
              </tr>
              <tr>
                <th style={styles.th}>
                  Source writeup IDs
                  <br />
                  <small>
                    (get &apos;em from the{' '}
                    <LinkNode title="Altar of Sacrifice" />)
                  </small>
                </th>
                <th style={styles.th}>Target node names</th>
              </tr>
              <tr>
                <td style={styles.td}>
                  <textarea
                    value={writeupIds}
                    onChange={(e) => setWriteupIds(e.target.value)}
                    rows={20}
                    cols={30}
                    style={styles.textarea}
                    placeholder="One writeup ID per line"
                  />
                </td>
                <td style={styles.td}>
                  <textarea
                    value={destinations}
                    onChange={(e) => setDestinations(e.target.value)}
                    rows={20}
                    cols={30}
                    style={styles.textarea}
                    placeholder="One e2node title per line"
                  />
                </td>
              </tr>
              <tr>
                <td colSpan={2} style={{ ...styles.td, textAlign: 'center' }}>
                  <button type="submit" style={styles.button} disabled={isLoading}>
                    {isLoading ? 'Validating...' : 'Validate'}
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </form>
      )}

      {/* Step 2: Preview */}
      {step === 'preview' && validatedData && (
        <div>
          <table style={styles.table}>
            <tbody>
              <tr>
                <td colSpan={2} style={styles.td}>
                  The following writeups by <strong>{validatedData.user.title}</strong> are ready to
                  be reparented. Nothing has happened to them ... yet.
                </td>
              </tr>
              <tr>
                <th style={styles.th}>Writeups to reparent</th>
                <th style={styles.th}>New homes</th>
              </tr>
              <tr>
                <td style={styles.td}>
                  <ol style={styles.list}>
                    {validatedData.writeups.map((wu, idx) => (
                      <li key={idx}>
                        <LinkNode id={wu.node_id} display={wu.title} />
                      </li>
                    ))}
                  </ol>
                </td>
                <td style={styles.td}>
                  <ol style={styles.list}>
                    {validatedData.destinations.map((dest, idx) => (
                      <li key={idx}>
                        <LinkNode id={dest.node_id} display={dest.title} />
                      </li>
                    ))}
                  </ol>
                </td>
              </tr>
              <tr>
                <td colSpan={2} style={{ ...styles.td, textAlign: 'center' }}>
                  <button onClick={handleExecute} style={styles.button} disabled={isLoading}>
                    {isLoading ? 'Moving...' : 'Do it!'}
                  </button>{' '}
                  <button onClick={handleReset} style={styles.buttonSecondary} disabled={isLoading}>
                    Cancel
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      )}

      {/* Step 3: Results */}
      {step === 'complete' && results && (
        <div>
          <div
            style={{
              ...styles.resultsBox,
              ...(results.every((r) => r.success)
                ? styles.resultsBoxSuccess
                : results.every((r) => !r.success)
                  ? styles.resultsBoxError
                  : styles.resultsBoxMixed)
            }}
          >
            <strong>
              Results: {results.filter((r) => r.success).length} moved,{' '}
              {results.filter((r) => !r.success).length} failed
            </strong>
            <ul style={styles.resultsList}>
              {results.map((r, idx) => (
                <li key={idx} style={r.success ? styles.resultSuccess : styles.resultError}>
                  {r.success ? (
                    <>
                      {r.old_title} moved to{' '}
                      <LinkNode id={r.new_parent_node_id} display={r.destTitle} />
                    </>
                  ) : (
                    <>
                      Failed: {r.old_title} - {r.error}
                    </>
                  )}
                </li>
              ))}
            </ul>
          </div>
          <div style={{ textAlign: 'center', marginTop: '15px' }}>
            <button onClick={handleReset} style={styles.button}>
              Start Over
            </button>
          </div>
        </div>
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
  welcome: {
    marginBottom: '15px',
    color: '#507898'
  },
  table: {
    width: '100%',
    borderCollapse: 'collapse',
    border: '1px solid #d3d3d3'
  },
  th: {
    backgroundColor: '#38495e',
    color: '#ffffff',
    padding: '10px',
    textAlign: 'left',
    borderBottom: '1px solid #d3d3d3'
  },
  td: {
    padding: '10px',
    borderBottom: '1px solid #e0e0e0',
    verticalAlign: 'top'
  },
  input: {
    padding: '6px 10px',
    fontSize: '13px',
    border: '1px solid #d3d3d3',
    borderRadius: '3px',
    width: '200px'
  },
  textarea: {
    width: '100%',
    padding: '8px',
    fontSize: '13px',
    border: '1px solid #d3d3d3',
    borderRadius: '3px',
    fontFamily: 'monospace',
    resize: 'vertical'
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
  buttonSecondary: {
    padding: '8px 20px',
    backgroundColor: '#f0f0f0',
    color: '#333',
    border: '1px solid #d3d3d3',
    borderRadius: '3px',
    cursor: 'pointer',
    fontSize: '13px'
  },
  errorBox: {
    backgroundColor: '#ffebee',
    border: '1px solid #f44336',
    borderRadius: '4px',
    padding: '15px',
    color: '#c62828',
    marginBottom: '15px'
  },
  errorList: {
    margin: '10px 0 0 0',
    paddingLeft: '20px'
  },
  list: {
    margin: '0',
    paddingLeft: '25px'
  },
  resultsBox: {
    padding: '15px',
    borderRadius: '4px',
    marginTop: '15px'
  },
  resultsBoxSuccess: {
    backgroundColor: '#e8f5e9',
    border: '2px solid #4caf50'
  },
  resultsBoxError: {
    backgroundColor: '#ffebee',
    border: '2px solid #f44336'
  },
  resultsBoxMixed: {
    backgroundColor: '#fff3e0',
    border: '2px solid #ff9800'
  },
  resultsList: {
    margin: '10px 0 0 0',
    paddingLeft: '20px'
  },
  resultSuccess: {
    color: '#2e7d32'
  },
  resultError: {
    color: '#c62828'
  }
}

export default KlaprothVanLines
