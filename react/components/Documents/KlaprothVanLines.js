import React, { useState } from 'react'
import LinkNode from '../LinkNode'

/**
 * KlaprothVanLines - Bulk reparenting of writeups for a single user.
 * Styles in CSS: .klaproth-van-lines__*
 *
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
      <div className="klaproth-van-lines">
        <p className="klaproth-van-lines__welcome">
          Welcome to Klaproth Van Lines. This utility will reparent writeups for a single user in
          bulk.
        </p>
        <div className="klaproth-van-lines__error-box">
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

  const getResultsBoxClass = () => {
    if (!results) return 'klaproth-van-lines__results-box'
    if (results.every((r) => r.success)) return 'klaproth-van-lines__results-box klaproth-van-lines__results-box--success'
    if (results.every((r) => !r.success)) return 'klaproth-van-lines__results-box klaproth-van-lines__results-box--error'
    return 'klaproth-van-lines__results-box klaproth-van-lines__results-box--mixed'
  }

  return (
    <div className="klaproth-van-lines">
      <p className="klaproth-van-lines__welcome">
        Welcome to Klaproth Van Lines. This utility will reparent writeups for a single user in
        bulk.
      </p>

      {/* Validation errors */}
      {validationErrors.length > 0 && (
        <div className="klaproth-van-lines__error-box">
          <strong>Errors:</strong>
          <ul className="klaproth-van-lines__error-list">
            {validationErrors.map((err, idx) => (
              <li key={idx}>{err}</li>
            ))}
          </ul>
        </div>
      )}

      {/* Step 1: Input form */}
      {step === 'input' && (
        <form onSubmit={handleValidate}>
          <div className="klaproth-van-lines__panel">
            <div className="klaproth-van-lines__username-row">
              <label>
                <strong>Username:</strong>{' '}
                <input
                  type="text"
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  className="klaproth-van-lines__input"
                  placeholder="Enter username"
                />
              </label>
            </div>
            <div className="klaproth-van-lines__columns">
              <div className="klaproth-van-lines__column">
                <div className="klaproth-van-lines__th">
                  Source writeup IDs
                  <br />
                  <small>
                    (get &apos;em from the{' '}
                    <LinkNode title="Altar of Sacrifice" />)
                  </small>
                </div>
                <div className="klaproth-van-lines__td">
                  <textarea
                    value={writeupIds}
                    onChange={(e) => setWriteupIds(e.target.value)}
                    rows={20}
                    className="klaproth-van-lines__textarea"
                    placeholder="One writeup ID per line"
                  />
                </div>
              </div>
              <div className="klaproth-van-lines__column">
                <div className="klaproth-van-lines__th">Target node names</div>
                <div className="klaproth-van-lines__td">
                  <textarea
                    value={destinations}
                    onChange={(e) => setDestinations(e.target.value)}
                    rows={20}
                    className="klaproth-van-lines__textarea"
                    placeholder="One e2node title per line"
                  />
                </div>
              </div>
            </div>
            <div className="klaproth-van-lines__td klaproth-van-lines__td--center">
              <button type="submit" className="klaproth-van-lines__button" disabled={isLoading}>
                {isLoading ? 'Validating...' : 'Validate'}
              </button>
            </div>
          </div>
        </form>
      )}

      {/* Step 2: Preview */}
      {step === 'preview' && validatedData && (
        <div>
          <div className="klaproth-van-lines__panel">
            <div className="klaproth-van-lines__td">
              The following writeups by <strong>{validatedData.user.title}</strong> are ready to
              be reparented. Nothing has happened to them ... yet.
            </div>
            <div className="klaproth-van-lines__columns">
              <div className="klaproth-van-lines__column">
                <div className="klaproth-van-lines__th">Writeups to reparent</div>
                <div className="klaproth-van-lines__td">
                  <ol className="klaproth-van-lines__list">
                    {validatedData.writeups.map((wu, idx) => (
                      <li key={idx}>
                        <LinkNode id={wu.node_id} display={wu.title} />
                      </li>
                    ))}
                  </ol>
                </div>
              </div>
              <div className="klaproth-van-lines__column">
                <div className="klaproth-van-lines__th">New homes</div>
                <div className="klaproth-van-lines__td">
                  <ol className="klaproth-van-lines__list">
                    {validatedData.destinations.map((dest, idx) => (
                      <li key={idx}>
                        <LinkNode id={dest.node_id} display={dest.title} />
                      </li>
                    ))}
                  </ol>
                </div>
              </div>
            </div>
            <div className="klaproth-van-lines__td klaproth-van-lines__td--center">
              <button onClick={handleExecute} className="klaproth-van-lines__button" disabled={isLoading}>
                {isLoading ? 'Moving...' : 'Do it!'}
              </button>{' '}
              <button onClick={handleReset} className="klaproth-van-lines__button-secondary" disabled={isLoading}>
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Step 3: Results */}
      {step === 'complete' && results && (
        <div>
          <div className={getResultsBoxClass()}>
            <strong>
              Results: {results.filter((r) => r.success).length} moved,{' '}
              {results.filter((r) => !r.success).length} failed
            </strong>
            <ul className="klaproth-van-lines__results-list">
              {results.map((r, idx) => (
                <li key={idx} className={r.success ? 'klaproth-van-lines__result-success' : 'klaproth-van-lines__result-error'}>
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
          <div className="klaproth-van-lines__actions">
            <button onClick={handleReset} className="klaproth-van-lines__button">
              Start Over
            </button>
          </div>
        </div>
      )}
    </div>
  )
}

export default KlaprothVanLines
