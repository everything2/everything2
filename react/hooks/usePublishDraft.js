import { useState, useEffect, useCallback } from 'react'
import { fetchWithErrorReporting, reportClientError } from '../utils/reportClientError'

/**
 * Hook to fetch available writeup types
 *
 * Returns writeuptypes array and selected writeuptype ID state
 * Defaults to 'thing' type if available
 *
 * @param {Object} options
 * @param {boolean} options.skip - If true, skip fetching (for editing existing writeups)
 */
export const useWriteuptypes = ({ skip = false } = {}) => {
  const [writeuptypes, setWriteuptypes] = useState([])
  const [selectedWriteuptypeId, setSelectedWriteuptypeId] = useState(null)
  const [loading, setLoading] = useState(!skip)
  const [error, setError] = useState(null)

  useEffect(() => {
    if (skip) {
      setLoading(false)
      return
    }

    const fetchWriteuptypes = async () => {
      try {
        setLoading(true)
        const response = await fetchWithErrorReporting(
          '/api/writeuptypes',
          {},
          'fetching writeup types'
        )
        const result = await response.json()

        if (result.success && result.writeuptypes) {
          setWriteuptypes(result.writeuptypes)
          // Default to 'thing' type if available
          const thingType = result.writeuptypes.find(wt => wt.title === 'thing')
          if (thingType) {
            setSelectedWriteuptypeId(thingType.node_id)
          } else if (result.writeuptypes.length > 0) {
            setSelectedWriteuptypeId(result.writeuptypes[0].node_id)
          }
        } else {
          setError('Failed to load writeup types')
        }
      } catch (err) {
        console.error('Failed to fetch writeuptypes:', err)
        setError(err.message)
      } finally {
        setLoading(false)
      }
    }

    fetchWriteuptypes()
  }, [skip])

  return {
    writeuptypes,
    selectedWriteuptypeId,
    setSelectedWriteuptypeId,
    loading,
    error
  }
}

/**
 * Hook to handle publishing a draft as a writeup
 *
 * Features:
 * - Automatic retry with exponential backoff (up to 3 attempts)
 * - Idempotent handling - succeeds gracefully if draft was already published
 * - Distinguishes between retryable errors (network) and non-retryable (validation)
 *
 * @param {Object} options
 * @param {number} options.draftId - The draft node ID
 * @param {Function} options.onSuccess - Callback on successful publish
 * @param {number} options.maxRetries - Maximum retry attempts (default: 3)
 */
export const usePublishDraft = ({ draftId, onSuccess, maxRetries = 3 }) => {
  const [publishing, setPublishing] = useState(false)
  const [error, setError] = useState(null)
  const [retryCount, setRetryCount] = useState(0)

  const publishDraft = useCallback(async ({
    parentE2nodeId,
    writeuptypeId,
    hideFromNewWriteups = false
  }) => {
    if (!draftId) {
      setError('No draft to publish')
      return { success: false }
    }

    if (!parentE2nodeId) {
      setError('Parent e2node is required')
      return { success: false }
    }

    if (!writeuptypeId) {
      setError('Please select a writeup type')
      return { success: false }
    }

    setPublishing(true)
    setError(null)
    setRetryCount(0)

    let lastError = null

    for (let attempt = 1; attempt <= maxRetries; attempt++) {
      setRetryCount(attempt)

      try {
        const response = await fetchWithErrorReporting(
          `/api/drafts/${draftId}/publish`,
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            credentials: 'include',
            body: JSON.stringify({
              parent_e2node: parentE2nodeId,
              wrtype_writeuptype: writeuptypeId,
              feedback_policy_id: 0,
              notnew: hideFromNewWriteups ? 1 : 0
            })
          },
          'publishing draft'
        )

        const result = await response.json()

        if (result.success) {
          // Handle both fresh publish and already-published (idempotent) responses
          if (result.already_published) {
            console.log('Draft was already published (idempotent success)')
          }

          if (onSuccess) {
            onSuccess(result)
          }
          setPublishing(false)
          return { success: true, result, alreadyPublished: !!result.already_published }
        } else {
          lastError = result.message || result.error || 'Publish failed'

          // Non-retryable errors - exit immediately
          const nonRetryableErrors = [
            'permission_denied',
            'not_a_draft',
            'invalid_writeuptype',
            'invalid_parent',
            'node_locked',
            'missing_parent',
            'missing_writeuptype'
          ]

          if (nonRetryableErrors.includes(result.error)) {
            setError(lastError)
            reportClientError('api_error', lastError, {
              action: 'publishing draft',
              draft_id: draftId,
              response_data: result
            })
            setPublishing(false)
            return { success: false, error: lastError }
          }
        }
      } catch (err) {
        lastError = err.message
        // Network/parsing errors are worth retrying
      }

      // Wait before retry (exponential backoff: 1s, 2s, 4s)
      if (attempt < maxRetries) {
        await new Promise(resolve => setTimeout(resolve, 1000 * Math.pow(2, attempt - 1)))
      }
    }

    // All retries exhausted
    const finalError = `Publish failed after ${maxRetries} attempts: ${lastError}`
    setError(finalError)
    reportClientError('api_error', finalError, {
      action: 'publishing draft (all retries failed)',
      draft_id: draftId,
      attempts: maxRetries
    })
    setPublishing(false)
    return { success: false, error: finalError }
  }, [draftId, onSuccess, maxRetries])

  return {
    publishDraft,
    publishing,
    error,
    setError,
    retryCount
  }
}

/**
 * Hook to set the parent e2node for a draft (creates if needed)
 */
export const useSetParentE2node = () => {
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)

  const setParentE2node = useCallback(async (draftId, e2nodeTitle, existingE2nodeId = null) => {
    if (!draftId) {
      setError('No draft specified')
      return { success: false }
    }

    if (!e2nodeTitle?.trim()) {
      setError('Please enter an e2node title')
      return { success: false }
    }

    setLoading(true)
    setError(null)

    try {
      const response = await fetchWithErrorReporting(
        `/api/drafts/${draftId}/parent`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          credentials: 'include',
          body: JSON.stringify({
            e2node_title: e2nodeTitle.trim(),
            e2node_id: existingE2nodeId || null
          })
        },
        'setting parent e2node'
      )

      const result = await response.json()

      if (result.success) {
        return { success: true, e2node: result.e2node }
      } else {
        const errorMsg = result.message || result.error || 'Failed to set parent e2node'
        setError(errorMsg)
        return { success: false, error: errorMsg }
      }
    } catch (err) {
      setError(err.message)
      return { success: false, error: err.message }
    } finally {
      setLoading(false)
    }
  }, [])

  return {
    setParentE2node,
    loading,
    error,
    setError
  }
}

export default usePublishDraft
