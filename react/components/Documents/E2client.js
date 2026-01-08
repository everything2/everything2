import React from 'react'
import LinkNode from '../LinkNode'
import { FaCode, FaDownload, FaHome, FaUser, FaEdit, FaTerminal } from 'react-icons/fa'
import { renderE2Content } from '../Editor/E2HtmlSanitizer'

/**
 * E2client - Display e2client (API client application) information
 *
 * Shows:
 * - Client name and version
 * - Home URL and download URL
 * - Client string (user agent identifier)
 * - Description
 * - Author information
 */
const E2client = ({ data }) => {
  const { e2client, can_edit } = data

  return (
    <div style={styles.container}>
      {/* Header */}
      <div style={styles.header}>
        <FaCode style={{ color: '#507898', marginRight: 8, fontSize: 24 }} />
        <div style={styles.headerInfo}>
          <h1 style={styles.title}>{e2client.title}</h1>
          {e2client.version && (
            <span style={styles.version}>v{e2client.version}</span>
          )}
        </div>
        {can_edit && (
          <a
            href={`/?node_id=${e2client.node_id}&displaytype=edit`}
            style={styles.editLink}
          >
            <FaEdit style={{ marginRight: 4 }} />
            edit
          </a>
        )}
      </div>

      {/* Author info */}
      <div style={styles.meta}>
        <FaUser style={{ marginRight: 6, color: '#507898' }} />
        Created by: <LinkNode {...e2client.author} type="user" />
        {e2client.createtime && (
          <span style={styles.createtime}> on {e2client.createtime}</span>
        )}
      </div>

      {/* URLs section */}
      {(e2client.homeurl || e2client.dlurl) && (
        <div style={styles.urlSection}>
          {e2client.homeurl && (
            <div style={styles.urlRow}>
              <FaHome style={styles.urlIcon} />
              <span style={styles.urlLabel}>Home:</span>
              <a href={e2client.homeurl} style={styles.urlLink} target="_blank" rel="noopener noreferrer">
                {e2client.homeurl}
              </a>
            </div>
          )}
          {e2client.dlurl && (
            <div style={styles.urlRow}>
              <FaDownload style={styles.urlIcon} />
              <span style={styles.urlLabel}>Download:</span>
              <a href={e2client.dlurl} style={styles.urlLink} target="_blank" rel="noopener noreferrer">
                {e2client.dlurl}
              </a>
            </div>
          )}
        </div>
      )}

      {/* Client string */}
      {e2client.clientstr && (
        <div style={styles.clientstrSection}>
          <FaTerminal style={{ marginRight: 6, color: '#507898' }} />
          <span style={styles.clientstrLabel}>Client String:</span>
          <code style={styles.clientstrValue}>{e2client.clientstr}</code>
        </div>
      )}

      {/* Description */}
      {e2client.doctext && (
        <div style={styles.description}>
          <h3 style={styles.sectionTitle}>Description</h3>
          <div
            style={styles.doctext}
            dangerouslySetInnerHTML={{ __html: renderE2Content(e2client.doctext).html }}
          />
        </div>
      )}

      {/* Empty state */}
      {!e2client.doctext && !e2client.homeurl && !e2client.dlurl && !e2client.clientstr && (
        <div style={styles.emptyState}>
          No additional information available for this client.
          {can_edit && (
            <span> <a href={`/?node_id=${e2client.node_id}&displaytype=edit`}>Add some details?</a></span>
          )}
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
    marginBottom: 16,
    paddingBottom: 16,
    borderBottom: '2px solid #38495e'
  },
  headerInfo: {
    flex: 1,
    display: 'flex',
    alignItems: 'baseline',
    gap: 12
  },
  title: {
    margin: 0,
    fontSize: 24,
    fontWeight: 'bold',
    color: '#38495e'
  },
  version: {
    fontSize: 14,
    color: '#507898',
    backgroundColor: '#e8f4f8',
    padding: '2px 8px',
    borderRadius: 4
  },
  editLink: {
    display: 'flex',
    alignItems: 'center',
    fontSize: 14,
    color: '#4060b0',
    textDecoration: 'none'
  },
  meta: {
    display: 'flex',
    alignItems: 'center',
    fontSize: 14,
    color: '#38495e',
    marginBottom: 20
  },
  createtime: {
    color: '#666',
    marginLeft: 4
  },
  urlSection: {
    backgroundColor: '#f8f9fa',
    borderRadius: 4,
    padding: 16,
    marginBottom: 20
  },
  urlRow: {
    display: 'flex',
    alignItems: 'center',
    marginBottom: 8
  },
  urlIcon: {
    color: '#507898',
    marginRight: 8,
    width: 16
  },
  urlLabel: {
    fontWeight: 'bold',
    color: '#38495e',
    marginRight: 8,
    minWidth: 80
  },
  urlLink: {
    color: '#4060b0',
    wordBreak: 'break-all'
  },
  clientstrSection: {
    display: 'flex',
    alignItems: 'center',
    flexWrap: 'wrap',
    gap: 8,
    padding: 12,
    backgroundColor: '#f0f0f0',
    borderRadius: 4,
    marginBottom: 20
  },
  clientstrLabel: {
    fontWeight: 'bold',
    color: '#38495e'
  },
  clientstrValue: {
    backgroundColor: '#fff',
    padding: '4px 8px',
    borderRadius: 4,
    border: '1px solid #ddd',
    fontFamily: 'monospace',
    fontSize: 13,
    wordBreak: 'break-all'
  },
  description: {
    marginTop: 20
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#38495e',
    marginBottom: 12,
    paddingBottom: 8,
    borderBottom: '1px solid #ddd'
  },
  doctext: {
    lineHeight: 1.6,
    color: '#333'
  },
  emptyState: {
    padding: 20,
    textAlign: 'center',
    color: '#666',
    backgroundColor: '#f8f9fa',
    borderRadius: 4
  }
}

export default E2client
