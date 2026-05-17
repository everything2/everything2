import React from 'react'
import LinkNode from '../LinkNode'
import { FaMicrophone, FaDownload, FaUser, FaFileAlt, FaPodcast } from 'react-icons/fa'

/**
 * Recording - Display recording information
 * Styles in CSS: .recording__*
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
    <div className="recording">
      {/* Header */}
      <div className="recording__header">
        <FaMicrophone className="recording__header-icon" />
        <span className="recording__title">{recording.title}</span>
      </div>

      {/* Audio file link */}
      {recording.link && (
        <div className="recording__download-section">
          <a href={recording.link} className="recording__download-link" target="_blank" rel="noopener noreferrer">
            <FaDownload className="recording__download-icon" />
            audio file
          </a>
        </div>
      )}

      {/* Recording of (writeup) */}
      {recording.recording_of && (
        <div className="recording__info-section">
          <h3 className="recording__section-title">
            <FaFileAlt className="recording__section-icon" />
            A recording of
          </h3>
          <div className="recording__info-content">
            <LinkNode nodeId={recording.recording_of.node_id} title={recording.recording_of.title} />
            {recording.recording_of.author && (
              <div className="recording__sub-info">
                Written by <LinkNode nodeId={recording.recording_of.author.node_id} title={recording.recording_of.author.title} />
              </div>
            )}
          </div>
        </div>
      )}

      {/* Read by */}
      {recording.read_by && (
        <div className="recording__info-section">
          <h3 className="recording__section-title">
            <FaUser className="recording__section-icon" />
            Read by
          </h3>
          <div className="recording__info-content">
            <LinkNode nodeId={recording.read_by.node_id} title={recording.read_by.title} />
          </div>
        </div>
      )}

      {/* Appears in (podcast) */}
      {recording.appears_in && (
        <div className="recording__info-section">
          <h3 className="recording__section-title">
            <FaPodcast className="recording__section-icon" />
            Appears in
          </h3>
          <div className="recording__info-content">
            <LinkNode nodeId={recording.appears_in.node_id} title={recording.appears_in.title} />
          </div>
        </div>
      )}

      {/* Edit link */}
      {can_edit === 1 && (
        <div className="recording__edit-section">
          <a href={`/?node_id=${recording.node_id}&displaytype=edit&lastnode_id=0`} className="recording__edit-link">
            edit
          </a>
        </div>
      )}
    </div>
  )
}

export default Recording
