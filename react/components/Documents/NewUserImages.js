import React, { useState, useCallback } from 'react'

/**
 * NewUserImages - Admin tool to review user images
 * Styles in CSS: .new-user-images__*
 */

const ImageCard = ({ image, onApprove, onDelete }) => {
  const [loading, setLoading] = useState(false)
  const [status, setStatus] = useState(null)
  const [processed, setProcessed] = useState(false)

  const handleAction = useCallback(async (action) => {
    setLoading(true)
    setStatus(null)

    try {
      const response = await fetch(`/api/userimages/${action}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ userId: image.userId }),
      })

      const data = await response.json()

      if (data.success) {
        setStatus({ type: 'success', message: data.message })
        setProcessed(true)
        if (action === 'approve') {
          onApprove?.(image.id)
        } else {
          onDelete?.(image.id)
        }
      } else {
        setStatus({ type: 'error', message: data.error || 'Action failed' })
      }
    } catch (err) {
      setStatus({ type: 'error', message: 'Failed to connect to server' })
    } finally {
      setLoading(false)
    }
  }, [image, onApprove, onDelete])

  const cardClass = `new-user-images__card${processed ? ' new-user-images__card--processed' : ''}`

  return (
    <div className={cardClass}>
      {image.imageUrl ? (
        <img src={image.imageUrl} alt={`${image.userName}'s avatar`} className="new-user-images__image" />
      ) : (
        <div className="new-user-images__no-image">No image available</div>
      )}

      <div className="new-user-images__user-info">
        Posted by{' '}
        <a
          href={`/user/${encodeURIComponent(image.userName)}`}
          title={image.userName}
          className="new-user-images__user-link"
        >
          {image.userName}
        </a>
      </div>

      {!processed && (
        <div className="new-user-images__actions">
          <button
            onClick={() => handleAction('approve')}
            disabled={loading}
            className={`new-user-images__button new-user-images__button--approve${loading ? ' new-user-images__button--disabled' : ''}`}
          >
            {loading ? 'Processing...' : 'Approve'}
          </button>
          <button
            onClick={() => handleAction('delete')}
            disabled={loading}
            className={`new-user-images__button new-user-images__button--delete${loading ? ' new-user-images__button--disabled' : ''}`}
          >
            {loading ? 'Processing...' : 'Remove'}
          </button>
        </div>
      )}

      {status && (
        <div className={`new-user-images__status new-user-images__status--${status.type}`}>
          {status.message}
        </div>
      )}
    </div>
  )
}

const NewUserImages = ({ data }) => {
  const { images: initialImages, count } = data?.newUserImages || { images: [], count: 0 }
  const [images, setImages] = useState(initialImages)

  const handleProcessed = useCallback((id) => {
    // We keep the card visible but mark it as processed via the component state
  }, [])

  return (
    <div className="new-user-images">
      <div className="new-user-images__header">
        <h1 className="new-user-images__title">New User Images</h1>
        <div className="new-user-images__count">{count} pending image{count !== 1 ? 's' : ''}</div>
      </div>

      {images.length === 0 ? (
        <div className="new-user-images__empty">
          No pending user images to review.
        </div>
      ) : (
        <div className="new-user-images__list">
          {images.map((image) => (
            <ImageCard
              key={image.id}
              image={image}
              onApprove={handleProcessed}
              onDelete={handleProcessed}
            />
          ))}
        </div>
      )}
    </div>
  )
}

export default NewUserImages
