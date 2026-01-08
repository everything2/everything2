import React from 'react'
import LinkNode from '../LinkNode'
import { FaMicrophone, FaDownload, FaUser, FaFileAlt, FaPodcast } from 'react-icons/fa'

/**
 * Recording - Display recording information
 *
 * Shows recording details including:
 * - Audio file link
 * - What writeup it's a recording of
 * - Who read/recorded it
 * - What podcast it appears in
 */
const Recording = ({ data }) => {
  const { recording, can_edit } = data

  return (
    <div style={styles.container}>
      {/* Header */}
      <div style={styles.header}>
        <FaMicrophone style={{ color: '#507898', marginRight: 8, fontSize: 20 }} />
        <span style={styles.title}>{recording.title}</span>
      </div>

      {/* Audio file link */}
      {recording.link && (
        <div style={styles.downloadSection}>
          <a href={recording.link} style={styles.downloadLink} target="_blank" rel="noopener noreferrer">
            <FaDownload style={{ marginRight: 8 }} />
            audio file
          </a>
        </div>
      )}

      {/* Recording of (writeup) */}
      {recording.recording_of && (
        <div style={styles.infoSection}>
          <h3 style={styles.sectionTitle}>
            <FaFileAlt style={{ marginRight: 6, color: '#507898' }} />
            A recording of
          </h3>
          <div style={styles.infoContent}>
            <LinkNode nodeId={recording.recording_of.node_id} title={recording.recording_of.title} />
            {recording.recording_of.author && (
              <div style={styles.subInfo}>
                Written by <LinkNode nodeId={recording.recording_of.author.node_id} title={recording.recording_of.author.title} />
              </div>
            )}
          </div>
        </div>
      )}

      {/* Read by */}
      {recording.read_by && (
        <div style={styles.infoSection}>
          <h3 style={styles.sectionTitle}>
            <FaUser style={{ marginRight: 6, color: '#507898' }} />
            Read by
          </h3>
          <div style={styles.infoContent}>
            <LinkNode nodeId={recording.read_by.node_id} title={recording.read_by.title} />
          </div>
        </div>
      )}

      {/* Appears in (podcast) */}
      {recording.appears_in && (
        <div style={styles.infoSection}>
          <h3 style={styles.sectionTitle}>
            <FaPodcast style={{ marginRight: 6, color: '#507898' }} />
            Appears in
          </h3>
          <div style={styles.infoContent}>
            <LinkNode nodeId={recording.appears_in.node_id} title={recording.appears_in.title} />
          </div>
        </div>
      )}

      {/* Edit link */}
      {can_edit === 1 && (
        <div style={styles.editSection}>
          <a href={`/?node_id=${recording.node_id}&displaytype=edit&lastnode_id=0`} style={styles.editLink}>
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
    marginBottom: 24
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
  infoSection: {
    marginBottom: 20,
    padding: 16,
    backgroundColor: '#f8f9fa',
    borderRadius: 4
  },
  sectionTitle: {
    display: 'flex',
    alignItems: 'center',
    fontSize: 14,
    fontWeight: 'bold',
    color: '#38495e',
    marginBottom: 8,
    marginTop: 0
  },
  infoContent: {
    paddingLeft: 24,
    fontSize: 15
  },
  subInfo: {
    marginTop: 4,
    fontSize: 13,
    color: '#666'
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

export default Recording
