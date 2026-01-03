import React, { useState, useCallback } from 'react'

const styles = {
  container: {
    maxWidth: '900px',
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
  count: {
    color: '#666',
    fontSize: '0.9rem',
    marginTop: '5px',
  },
  imageList: {
    display: 'flex',
    flexDirection: 'column',
    gap: '20px',
  },
  imageCard: {
    border: '1px solid #ddd',
    borderRadius: '8px',
    padding: '15px',
    backgroundColor: '#fafafa',
  },
  imageCardProcessed: {
    opacity: 0.5,
    backgroundColor: '#f0f0f0',
  },
  image: {
    maxWidth: '200px',
    maxHeight: '200px',
    border: '1px solid #ccc',
    borderRadius: '4px',
  },
  noImage: {
    width: '200px',
    height: '150px',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#eee',
    color: '#666',
    borderRadius: '4px',
  },
  userInfo: {
    marginTop: '10px',
    fontSize: '14px',
  },
  userLink: {
    fontWeight: 'bold',
  },
  actions: {
    marginTop: '15px',
    display: 'flex',
    gap: '10px',
  },
  button: {
    padding: '8px 16px',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
    fontSize: '14px',
    fontWeight: 'bold',
  },
  approveButton: {
    backgroundColor: '#28a745',
    color: 'white',
  },
  deleteButton: {
    backgroundColor: '#dc3545',
    color: 'white',
  },
  buttonDisabled: {
    opacity: 0.6,
    cursor: 'not-allowed',
  },
  statusMessage: {
    marginTop: '10px',
    padding: '8px',
    borderRadius: '4px',
    fontSize: '13px',
  },
  success: {
    backgroundColor: '#d4edda',
    color: '#155724',
  },
  error: {
    backgroundColor: '#f8d7da',
    color: '#721c24',
  },
  emptyMessage: {
    padding: '40px',
    textAlign: 'center',
    color: '#666',
    fontStyle: 'italic',
    backgroundColor: '#f8f9fa',
    borderRadius: '8px',
  },
}

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

  return (
    <div style={{
      ...styles.imageCard,
      ...(processed ? styles.imageCardProcessed : {})
    }}>
      {image.imageUrl ? (
        <img src={image.imageUrl} alt={`${image.userName}'s avatar`} style={styles.image} />
      ) : (
        <div style={styles.noImage}>No image available</div>
      )}

      <div style={styles.userInfo}>
        Posted by{' '}
        <a
          href={`/user/${encodeURIComponent(image.userName)}`}
          title={image.userName}
          style={styles.userLink}
        >
          {image.userName}
        </a>
      </div>

      {!processed && (
        <div style={styles.actions}>
          <button
            onClick={() => handleAction('approve')}
            disabled={loading}
            style={{
              ...styles.button,
              ...styles.approveButton,
              ...(loading ? styles.buttonDisabled : {})
            }}
          >
            {loading ? 'Processing...' : 'Approve'}
          </button>
          <button
            onClick={() => handleAction('delete')}
            disabled={loading}
            style={{
              ...styles.button,
              ...styles.deleteButton,
              ...(loading ? styles.buttonDisabled : {})
            }}
          >
            {loading ? 'Processing...' : 'Remove'}
          </button>
        </div>
      )}

      {status && (
        <div style={{
          ...styles.statusMessage,
          ...(status.type === 'success' ? styles.success : styles.error)
        }}>
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
    <div style={styles.container}>
      <div style={styles.header}>
        <h1 style={styles.title}>New User Images</h1>
        <div style={styles.count}>{count} pending image{count !== 1 ? 's' : ''}</div>
      </div>

      {images.length === 0 ? (
        <div style={styles.emptyMessage}>
          No pending user images to review.
        </div>
      ) : (
        <div style={styles.imageList}>
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
