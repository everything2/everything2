import React, { useState } from 'react'
import LinkNode from '../LinkNode'
import DateTimePicker from '../DateTimePicker'
import { FaPodcast, FaSave, FaTimes, FaMicrophone, FaPlus, FaSpinner } from 'react-icons/fa'

/**
 * PodcastEdit - Edit podcast information
 * Styles in CSS: .podcast-edit__*
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
    <div className="podcast-edit">
      {/* Header */}
      <div className="podcast-edit__header">
        <FaPodcast className="podcast-edit__header-icon" />
        <span className="podcast-edit__header-title">Edit Podcast</span>
        <a href={`/node/${podcast.node_id}`} className="podcast-edit__back-link">
          display
        </a>
      </div>

      {/* Message */}
      {message && (
        <div className={message.type === 'error' ? 'podcast-edit__error' : 'podcast-edit__success'}>
          {message.text}
        </div>
      )}

      {/* Form */}
      <div className="podcast-edit__form">
        <div className="podcast-edit__field">
          <label className="podcast-edit__label">Title:</label>
          <input
            type="text"
            value={formData.title}
            onChange={(e) => handleChange('title', e.target.value)}
            className="podcast-edit__input"
            maxLength={240}
          />
        </div>

        <div className="podcast-edit__field">
          <label className="podcast-edit__label">MP3 Link:</label>
          <input
            type="text"
            value={formData.link}
            onChange={(e) => handleChange('link', e.target.value)}
            className="podcast-edit__input"
            placeholder="https://..."
          />
        </div>

        <div className="podcast-edit__field">
          <label className="podcast-edit__label">Description:</label>
          <textarea
            value={formData.description}
            onChange={(e) => handleChange('description', e.target.value)}
            className="podcast-edit__textarea"
            rows={10}
          />
        </div>

        <div className="podcast-edit__field">
          <label className="podcast-edit__label">Publication Date:</label>
          <DateTimePicker
            value={formData.pubdate}
            onChange={(value) => handleChange('pubdate', value)}
            placeholder="Select publication date/time..."
          />
        </div>

        <div className="podcast-edit__button-row">
          <button
            onClick={handleSave}
            disabled={saving}
            className="podcast-edit__submit-button"
          >
            {saving ? <FaSpinner className="fa-spin" /> : <FaSave />}
            <span className="podcast-edit__button-text">{saving ? 'Saving...' : 'Save Changes'}</span>
          </button>
        </div>
      </div>

      {/* Recordings section */}
      <div className="podcast-edit__recordings-section">
        <h3 className="podcast-edit__recordings-header">
          <FaMicrophone className="podcast-edit__recordings-icon" />
          Recordings ({recordings.length})
        </h3>

        {recordings.length > 0 && (
          <ul className="podcast-edit__recordings-list">
            {recordings.map(recording => (
              <li key={recording.node_id} className="podcast-edit__recording-item">
                <span className="podcast-edit__recording-title">
                  <LinkNode nodeId={recording.node_id} title={recording.title} />
                </span>
                <a
                  href={`/?node_id=${recording.node_id}&displaytype=edit`}
                  className="podcast-edit__recording-edit"
                >
                  edit
                </a>
              </li>
            ))}
          </ul>
        )}

        {/* Add new recording */}
        <div className="podcast-edit__add-recording">
          <h4 className="podcast-edit__add-title">Add a new recording:</h4>
          <form onSubmit={handleCreateRecording} className="podcast-edit__add-form">
            <input
              type="text"
              value={newRecordingTitle}
              onChange={(e) => setNewRecordingTitle(e.target.value)}
              className="podcast-edit__add-input"
              placeholder="Recording title"
              maxLength={64}
            />
            <button
              type="submit"
              disabled={creatingRecording || !newRecordingTitle.trim()}
              className="podcast-edit__add-button"
            >
              {creatingRecording ? <FaSpinner className="fa-spin" /> : <FaPlus />}
              <span className="podcast-edit__add-button-text">create</span>
            </button>
          </form>
        </div>
      </div>
    </div>
  )
}

export default PodcastEdit
