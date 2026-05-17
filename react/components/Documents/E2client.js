import React from 'react'
import LinkNode from '../LinkNode'
import { FaCode, FaDownload, FaHome, FaUser, FaEdit, FaTerminal } from 'react-icons/fa'
import { renderE2Content } from '../Editor/E2HtmlSanitizer'

/**
 * E2client - Display e2client (API client application) information
 * Styles in CSS: .e2client__*
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
    <div className="e2client">
      {/* Header */}
      <div className="e2client__header">
        <FaCode className="e2client__header-icon" />
        <div className="e2client__header-info">
          <h1 className="e2client__title">{e2client.title}</h1>
          {e2client.version && (
            <span className="e2client__version">v{e2client.version}</span>
          )}
        </div>
        {can_edit && (
          <a
            href={`/?node_id=${e2client.node_id}&displaytype=edit`}
            className="e2client__edit-link"
          >
            <FaEdit className="e2client__edit-icon" />
            edit
          </a>
        )}
      </div>

      {/* Author info */}
      <div className="e2client__meta">
        <FaUser className="e2client__meta-icon" />
        Created by: <LinkNode {...e2client.author} type="user" />
        {e2client.createtime && (
          <span className="e2client__createtime"> on {e2client.createtime}</span>
        )}
      </div>

      {/* URLs section */}
      {(e2client.homeurl || e2client.dlurl) && (
        <div className="e2client__url-section">
          {e2client.homeurl && (
            <div className="e2client__url-row">
              <FaHome className="e2client__url-icon" />
              <span className="e2client__url-label">Home:</span>
              <a href={e2client.homeurl} className="e2client__url-link" target="_blank" rel="noopener noreferrer">
                {e2client.homeurl}
              </a>
            </div>
          )}
          {e2client.dlurl && (
            <div className="e2client__url-row">
              <FaDownload className="e2client__url-icon" />
              <span className="e2client__url-label">Download:</span>
              <a href={e2client.dlurl} className="e2client__url-link" target="_blank" rel="noopener noreferrer">
                {e2client.dlurl}
              </a>
            </div>
          )}
        </div>
      )}

      {/* Client string */}
      {e2client.clientstr && (
        <div className="e2client__clientstr-section">
          <FaTerminal className="e2client__clientstr-icon" />
          <span className="e2client__clientstr-label">Client String:</span>
          <code className="e2client__clientstr-value">{e2client.clientstr}</code>
        </div>
      )}

      {/* Description */}
      {e2client.doctext && (
        <div className="e2client__description">
          <h3 className="e2client__section-title">Description</h3>
          <div
            className="e2client__doctext"
            dangerouslySetInnerHTML={{ __html: renderE2Content(e2client.doctext).html }}
          />
        </div>
      )}

      {/* Empty state */}
      {!e2client.doctext && !e2client.homeurl && !e2client.dlurl && !e2client.clientstr && (
        <div className="e2client__empty-state">
          No additional information available for this client.
          {can_edit && (
            <span> <a href={`/?node_id=${e2client.node_id}&displaytype=edit`}>Add some details?</a></span>
          )}
        </div>
      )}
    </div>
  )
}

export default E2client
