import React from 'react'
import LinkNode from '../LinkNode'
import { FaPodcast, FaDownload, FaMicrophone, FaUser, FaFileAlt } from 'react-icons/fa'
import { renderE2Content } from '../Editor/E2HtmlSanitizer'

/**
 * Podcast - Display podcast information and recordings
 *
 * Shows podcast details including description, download link,
 * and list of recordings associated with this podcast.
 */
const Podcast = ({ data }) => {
  const { podcast, recordings, can_edit } = data

  return (
    <div style={styles.container}>
      {/* Header */}
      <div style={styles.header}>
        <FaPodcast style={{ color: '#507898', marginRight: 8, fontSize: 20 }} />
        <span style={styles.title}>{podcast.title}</span>
      </div>

      {/* Download link */}
      {podcast.link && (
        <div style={styles.downloadSection}>
          <a href={podcast.link} style={styles.downloadLink} target="_blank" rel="noopener noreferrer">
            <FaDownload style={{ marginRight: 8 }} />
            Download MP3
          </a>
        </div>
      )}

      {/* Description */}
      {podcast.description && (
        <div
          style={styles.description}
          dangerouslySetInnerHTML={{ __html: renderE2Content(podcast.description).html }}
        />
      )}

      {/* Author */}
      <div style={styles.authorSection}>
        <span>Created by <LinkNode nodeId={podcast.author.node_id} title={podcast.author.title} /></span>
      </div>

      {/* Recordings section */}
      {recordings && recordings.length > 0 && (
        <div style={styles.recordingsSection}>
          <h3 style={styles.sectionTitle}>
            <FaMicrophone style={{ marginRight: 6 }} />
            Recordings ({recordings.length})
          </h3>

          <div style={styles.recordingsList}>
            {recordings.map((recording) => (
              <div key={recording.node_id} style={styles.recordingItem}>
                <div style={styles.recordingHeader}>
                  <LinkNode nodeId={recording.node_id} title={recording.title} />
                  {recording.link && (
                    <a href={recording.link} style={styles.recordingDownload} target="_blank" rel="noopener noreferrer">
                      <FaDownload /> audio
                    </a>
                  )}
                </div>

                {recording.recording_of && (
                  <div style={styles.recordingMeta}>
                    <FaFileAlt style={{ marginRight: 4, color: '#507898' }} />
                    Recording of: <LinkNode nodeId={recording.recording_of.node_id} title={recording.recording_of.title} />
                  </div>
                )}

                {recording.read_by && (
                  <div style={styles.recordingMeta}>
                    <FaUser style={{ marginRight: 4, color: '#507898' }} />
                    Read by: <LinkNode nodeId={recording.read_by.node_id} title={recording.read_by.title} />
                  </div>
                )}

                {recording.description && (
                  <div
                    style={styles.recordingDescription}
                    dangerouslySetInnerHTML={{ __html: renderE2Content(recording.description).html }}
                  />
                )}
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Edit link */}
      {can_edit === 1 && (
        <div style={styles.editSection}>
          <a href={`/?node_id=${podcast.node_id}&displaytype=edit&lastnode_id=0`} style={styles.editLink}>
            edit
          </a>
        </div>
      )}
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
    marginBottom: 16
  },
  title: {
    flex: 1
  },
  downloadSection: {
    textAlign: 'center',
    marginBottom: 20
  },
  downloadLink: {
    display: 'inline-flex',
    alignItems: 'center',
    padding: '12px 24px',
    backgroundColor: '#4060b0',
    color: '#fff',
    textDecoration: 'none',
    borderRadius: 4,
    fontSize: 16,
    fontWeight: 'bold'
  },
  description: {
    padding: 16,
    marginBottom: 16,
    backgroundColor: '#f8f9fa',
    borderRadius: 4,
    lineHeight: 1.6
  },
  authorSection: {
    textAlign: 'center',
    color: '#666',
    fontSize: 14,
    marginBottom: 24
  },
  recordingsSection: {
    marginTop: 24
  },
  sectionTitle: {
    display: 'flex',
    alignItems: 'center',
    fontSize: 16,
    fontWeight: 'bold',
    color: '#38495e',
    marginBottom: 16,
    paddingBottom: 8,
    borderBottom: '2px solid #38495e'
  },
  recordingsList: {
    display: 'flex',
    flexDirection: 'column',
    gap: 16
  },
  recordingItem: {
    padding: 16,
    backgroundColor: '#f8f9fa',
    borderRadius: 4,
    border: '1px solid #ddd'
  },
  recordingHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
    fontWeight: 'bold'
  },
  recordingDownload: {
    display: 'inline-flex',
    alignItems: 'center',
    gap: 4,
    padding: '4px 12px',
    backgroundColor: '#507898',
    color: '#fff',
    textDecoration: 'none',
    borderRadius: 4,
    fontSize: 12
  },
  recordingMeta: {
    display: 'flex',
    alignItems: 'center',
    fontSize: 13,
    color: '#666',
    marginBottom: 4
  },
  recordingDescription: {
    marginTop: 8,
    fontSize: 14,
    lineHeight: 1.5
  },
  editSection: {
    textAlign: 'right',
    marginTop: 16,
    paddingTop: 16,
    borderTop: '1px solid #eee'
  },
  editLink: {
    color: '#4060b0',
    textDecoration: 'none'
  }
}

export default Podcast
