import React, { useState } from 'react'
import LinkNode from '../LinkNode'
import DateTimePicker from '../DateTimePicker'
import { FaPodcast, FaSave, FaTimes, FaMicrophone, FaPlus, FaSpinner } from 'react-icons/fa'

/**
 * PodcastEdit - Edit podcast information
 *
 * Allows editing podcast metadata (title, description, link, pubdate)
 * and shows associated recordings with link to create new ones.
 */
const PodcastEdit = ({ data }) => {
  const { podcast, recordings, is_admin } = data

  const [formData, setFormData] = useState({
    title: podcast.title || '',
    link: podcast.link || '',
    description: podcast.description || '',
    pubdate: podcast.pubdate || ''
  })
  const [saving, setSaving] = useState(false)
  const [message, setMessage] = useState(null)
  const [newRecordingTitle, setNewRecordingTitle] = useState('')
  const [creatingRecording, setCreatingRecording] = useState(false)

  const handleChange = (field, value) => {
    setFormData(prev => ({ ...prev, [field]: value }))
    setMessage(null)
  }

  const handleSave = async () => {
    setSaving(true)
    setMessage(null)

    try {
      const response = await fetch(`/api/podcasts/${podcast.node_id}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify(formData)
      })

      const result = await response.json()

      if (result.success) {
        setMessage({ type: 'success', text: 'Podcast saved successfully!' })
      } else {
        setMessage({ type: 'error', text: result.error || 'Failed to save' })
      }
    } catch (err) {
      setMessage({ type: 'error', text: 'Network error: ' + err.message })
    } finally {
      setSaving(false)
    }
  }

  const handleCreateRecording = async (e) => {
    e.preventDefault()
    if (!newRecordingTitle.trim()) return

    setCreatingRecording(true)

    try {
      const response = await fetch('/api/recordings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({
          title: newRecordingTitle.trim(),
          appears_in: podcast.node_id
        })
      })

      const result = await response.json()

      if (result.success && result.node_id) {
        // Redirect to the new recording's edit page
        window.location.href = `/?node_id=${result.node_id}&displaytype=edit`
      } else {
        setMessage({ type: 'error', text: result.error || 'Failed to create recording' })
      }
    } catch (err) {
      setMessage({ type: 'error', text: 'Network error: ' + err.message })
    } finally {
      setCreatingRecording(false)
    }
  }

  return (
    <div style={styles.container}>
      {/* Header */}
      <div style={styles.header}>
        <FaPodcast style={{ color: '#507898', marginRight: 8, fontSize: 20 }} />
        <span style={styles.headerTitle}>Edit Podcast</span>
        <a href={`/node/${podcast.node_id}`} style={styles.displayLink}>
          display
        </a>
      </div>

      {/* Message */}
      {message && (
        <div style={{
          ...styles.message,
          backgroundColor: message.type === 'error' ? '#fee' : '#efe',
          borderColor: message.type === 'error' ? '#fcc' : '#cec',
          color: message.type === 'error' ? '#c00' : '#060'
        }}>
          {message.text}
        </div>
      )}

      {/* Form */}
      <div style={styles.form}>
        <div style={styles.field}>
          <label style={styles.label}>Title:</label>
          <input
            type="text"
            value={formData.title}
            onChange={(e) => handleChange('title', e.target.value)}
            style={styles.input}
            maxLength={240}
          />
        </div>

        <div style={styles.field}>
          <label style={styles.label}>MP3 Link:</label>
          <input
            type="text"
            value={formData.link}
            onChange={(e) => handleChange('link', e.target.value)}
            style={styles.input}
            placeholder="https://..."
          />
        </div>

        <div style={styles.field}>
          <label style={styles.label}>Description:</label>
          <textarea
            value={formData.description}
            onChange={(e) => handleChange('description', e.target.value)}
            style={styles.textarea}
            rows={10}
          />
        </div>

        <div style={styles.field}>
          <label style={styles.label}>Publication Date:</label>
          <DateTimePicker
            value={formData.pubdate}
            onChange={(value) => handleChange('pubdate', value)}
            placeholder="Select publication date/time..."
          />
        </div>

        <div style={styles.buttonRow}>
          <button
            onClick={handleSave}
            disabled={saving}
            style={styles.saveButton}
          >
            {saving ? <FaSpinner className="fa-spin" /> : <FaSave />}
            <span style={{ marginLeft: 6 }}>{saving ? 'Saving...' : 'Save Changes'}</span>
          </button>
        </div>
      </div>

      {/* Recordings section */}
      <div style={styles.recordingsSection}>
        <h3 style={styles.sectionTitle}>
          <FaMicrophone style={{ marginRight: 6 }} />
          Recordings ({recordings.length})
        </h3>

        {recordings.length > 0 && (
          <div style={styles.recordingsList}>
            {recordings.map(recording => (
              <div key={recording.node_id} style={styles.recordingItem}>
                <LinkNode nodeId={recording.node_id} title={recording.title} />
                <a
                  href={`/?node_id=${recording.node_id}&displaytype=edit`}
                  style={styles.editRecordingLink}
                >
                  edit
                </a>
              </div>
            ))}
          </div>
        )}

        {/* Add new recording */}
        <div style={styles.newRecordingSection}>
          <h4 style={styles.newRecordingTitle}>Add a new recording:</h4>
          <form onSubmit={handleCreateRecording} style={styles.newRecordingForm}>
            <input
              type="text"
              value={newRecordingTitle}
              onChange={(e) => setNewRecordingTitle(e.target.value)}
              style={styles.newRecordingInput}
              placeholder="Recording title"
              maxLength={64}
            />
            <button
              type="submit"
              disabled={creatingRecording || !newRecordingTitle.trim()}
              style={styles.createButton}
            >
              {creatingRecording ? <FaSpinner className="fa-spin" /> : <FaPlus />}
              <span style={{ marginLeft: 4 }}>create</span>
            </button>
          </form>
        </div>
      </div>
    </div>
  )
}

const styles = {
  container: {
    maxWidth: 800,
    margin: '0 auto',
    padding: '16px 0'
  },
  header: {
    display: 'flex',
    alignItems: 'center',
    fontSize: 18,
    fontWeight: 'bold',
    color: '#38495e',
    marginBottom: 16,
    paddingBottom: 12,
    borderBottom: '2px solid #38495e'
  },
  headerTitle: {
    flex: 1
  },
  displayLink: {
    fontSize: 14,
    color: '#4060b0',
    textDecoration: 'none'
  },
  message: {
    padding: 12,
    marginBottom: 16,
    borderRadius: 4,
    border: '1px solid'
  },
  form: {
    marginBottom: 24
  },
  field: {
    marginBottom: 16
  },
  label: {
    display: 'block',
    fontWeight: 'bold',
    marginBottom: 4,
    color: '#38495e'
  },
  input: {
    width: '100%',
    padding: '8px 10px',
    fontSize: 14,
    border: '1px solid #ccc',
    borderRadius: 4,
    boxSizing: 'border-box'
  },
  textarea: {
    width: '100%',
    padding: '8px 10px',
    fontSize: 14,
    border: '1px solid #ccc',
    borderRadius: 4,
    boxSizing: 'border-box',
    fontFamily: 'inherit',
    resize: 'vertical'
  },
  buttonRow: {
    marginTop: 20
  },
  saveButton: {
    display: 'inline-flex',
    alignItems: 'center',
    padding: '10px 20px',
    backgroundColor: '#4060b0',
    color: '#fff',
    border: 'none',
    borderRadius: 4,
    cursor: 'pointer',
    fontSize: 14,
    fontWeight: 'bold'
  },
  recordingsSection: {
    marginTop: 32,
    paddingTop: 20,
    borderTop: '1px solid #ddd'
  },
  sectionTitle: {
    display: 'flex',
    alignItems: 'center',
    fontSize: 16,
    fontWeight: 'bold',
    color: '#38495e',
    marginBottom: 16
  },
  recordingsList: {
    marginBottom: 20
  },
  recordingItem: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: '8px 12px',
    backgroundColor: '#f8f9fa',
    borderRadius: 4,
    marginBottom: 8
  },
  editRecordingLink: {
    fontSize: 12,
    color: '#4060b0',
    textDecoration: 'none'
  },
  newRecordingSection: {
    marginTop: 20,
    padding: 16,
    backgroundColor: '#f8f9fa',
    borderRadius: 4
  },
  newRecordingTitle: {
    fontSize: 14,
    fontWeight: 'bold',
    color: '#38495e',
    marginBottom: 12,
    marginTop: 0
  },
  newRecordingForm: {
    display: 'flex',
    gap: 8
  },
  newRecordingInput: {
    flex: 1,
    padding: '8px 10px',
    fontSize: 14,
    border: '1px solid #ccc',
    borderRadius: 4
  },
  createButton: {
    display: 'inline-flex',
    alignItems: 'center',
    padding: '8px 16px',
    backgroundColor: '#507898',
    color: '#fff',
    border: 'none',
    borderRadius: 4,
    cursor: 'pointer',
    fontSize: 14
  }
}

export default PodcastEdit
