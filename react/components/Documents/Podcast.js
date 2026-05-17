import React from 'react'
import LinkNode from '../LinkNode'
import { FaPodcast, FaDownload, FaMicrophone, FaUser, FaFileAlt } from 'react-icons/fa'
import { renderE2Content } from '../Editor/E2HtmlSanitizer'

/**
 * Podcast - Display podcast information and recordings
 * Styles in CSS: .podcast__*
 *
 * Shows podcast details including description, download link,
 * and list of recordings associated with this podcast.
 */
const Podcast = ({ data }) => {
  const { podcast, recordings, can_edit } = data

  return (
    <div className="podcast">
      {/* Header */}
      <div className="podcast__header">
        <FaPodcast className="podcast__header-icon" />
        <span className="podcast__title">{podcast.title}</span>
      </div>

      {/* Download link */}
      {podcast.link && (
        <div className="podcast__download-section">
          <a href={podcast.link} className="podcast__download-link" target="_blank" rel="noopener noreferrer">
            <FaDownload className="podcast__download-icon" />
            Download MP3
          </a>
        </div>
      )}

      {/* Description */}
      {podcast.description && (
        <div
          className="podcast__description"
          dangerouslySetInnerHTML={{ __html: renderE2Content(podcast.description).html }}
        />
      )}

      {/* Author */}
      <div className="podcast__author-section">
        <span>Created by <LinkNode nodeId={podcast.author.node_id} title={podcast.author.title} /></span>
      </div>

      {/* Recordings section */}
      {recordings && recordings.length > 0 && (
        <div className="podcast__recordings-section">
          <h3 className="podcast__section-title">
            <FaMicrophone className="podcast__section-icon" />
            Recordings ({recordings.length})
          </h3>

          <div className="podcast__recordings-list">
            {recordings.map((recording) => (
              <div key={recording.node_id} className="podcast__recording-item">
                <div className="podcast__recording-header">
                  <LinkNode nodeId={recording.node_id} title={recording.title} />
                  {recording.link && (
                    <a href={recording.link} className="podcast__recording-download" target="_blank" rel="noopener noreferrer">
                      <FaDownload /> audio
                    </a>
                  )}
                </div>

                {recording.recording_of && (
                  <div className="podcast__recording-meta">
                    <FaFileAlt className="podcast__recording-meta-icon" />
                    Recording of: <LinkNode nodeId={recording.recording_of.node_id} title={recording.recording_of.title} />
                  </div>
                )}

                {recording.read_by && (
                  <div className="podcast__recording-meta">
                    <FaUser className="podcast__recording-meta-icon" />
                    Read by: <LinkNode nodeId={recording.read_by.node_id} title={recording.read_by.title} />
                  </div>
                )}

                {recording.description && (
                  <div
                    className="podcast__recording-description"
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
        <div className="podcast__edit-section">
          <a href={`/?node_id=${podcast.node_id}&displaytype=edit&lastnode_id=0`} className="podcast__edit-link">
            edit
          </a>
        </div>
      )}
    </div>
  )
}

export default Podcast
