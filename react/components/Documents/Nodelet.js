import React from 'react'
import LinkNode from '../LinkNode'
import SourceMapDisplay from '../Developer/SourceMapDisplay'
import { FaList, FaClock, FaCode, FaFolder, FaCogs, FaInfoCircle } from 'react-icons/fa'

/**
 * Nodelet - Display page for nodelet nodes
 * Styles in CSS: .nodelet-display__*
 *
 * Modeled after the Nodetype display component.
 * Shows nodelet documentation, configuration, and source map.
 */
const Nodelet = ({ data, user }) => {
  if (!data || !data.nodelet) return null

  const { nodelet, sourceMap } = data
  const isDeveloper = user?.developer || user?.editor
  const {
    node_id,
    title,
    updateinterval = 0,
    parent_container,
    nlcode_preview,
    nltext_preview,
    has_react_component
  } = nodelet

  // Format update interval
  const formatUpdateInterval = (interval) => {
    if (!interval || interval === 0) {
      return 'No caching (updated every request)'
    }
    if (interval < 60) {
      return `${interval} second${interval !== 1 ? 's' : ''}`
    }
    if (interval < 3600) {
      const mins = Math.floor(interval / 60)
      return `${mins} minute${mins !== 1 ? 's' : ''}`
    }
    const hours = Math.floor(interval / 3600)
    return `${hours} hour${hours !== 1 ? 's' : ''}`
  }

  return (
    <div className="nodelet-display">
      {/* Quick Actions */}
      <div className="nodelet-display__actions">
        <a
          href={`/title/List%20Nodes%20of%20Type?setvars_ListNodesOfType_Type=9`}
          className="nodelet-display__list-btn"
        >
          <FaList size={12} /> List All Nodelets
        </a>
      </div>

      {/* About Section */}
      <div className="nodelet-display__section">
        <h4 className="nodelet-display__section-header">
          <FaInfoCircle size={16} /> About This Nodelet
        </h4>
        <p className="nodelet-display__about nodelet-display__value">
          Nodelets are sidebar widgets that appear in the right column of Everything2 pages.
          They provide quick access to information and features like chat, new writeups, and user stats.
          {has_react_component ? (
            <span className="nodelet-display__react-notice">
              <strong>This nodelet uses a React component for rendering.</strong>
            </span>
          ) : (
            <span className="nodelet-display__legacy-notice">
              This nodelet uses legacy Perl htmlcode for rendering.
            </span>
          )}
        </p>
      </div>

      {/* Configuration Section */}
      <div className="nodelet-display__section">
        <h4 className="nodelet-display__section-header">
          <FaCogs size={16} /> Configuration
        </h4>

        <div className="nodelet-display__grid">
          <div>
            <div className="nodelet-display__header">
              <FaClock size={12} /> Update Interval
            </div>
            <div className="nodelet-display__value">{formatUpdateInterval(updateinterval)}</div>
          </div>

          <div>
            <div className="nodelet-display__header">
              <FaFolder size={12} /> Parent Container
            </div>
            <div className="nodelet-display__value">
              {parent_container && parent_container !== 0 ? (
                <LinkNode nodeId={parent_container} title={`Node ${parent_container}`} />
              ) : (
                <span className="nodelet-display__empty">None (top-level nodelet)</span>
              )}
            </div>
          </div>
        </div>
      </div>

      {/* Code Preview Section (Developer only) */}
      {isDeveloper && (nlcode_preview || nltext_preview) && (
        <div className="nodelet-display__section">
          <h4 className="nodelet-display__section-header">
            <FaCode size={16} /> Code Preview
          </h4>

          {nlcode_preview && (
            <div className={nltext_preview ? 'nodelet-display__code-section' : ''}>
              <div className="nodelet-display__header">
                <FaCode size={12} /> nlcode (Perl code)
              </div>
              <div className="nodelet-display__code-preview">
                {nlcode_preview}
              </div>
            </div>
          )}

          {nltext_preview && (
            <div>
              <div className="nodelet-display__header">
                <FaCode size={12} /> nltext (HTML template)
              </div>
              <div className="nodelet-display__code-preview">
                {nltext_preview}
              </div>
            </div>
          )}
        </div>
      )}

      {/* Developer Source Map */}
      {isDeveloper && sourceMap && (
        <SourceMapDisplay
          sourceMap={sourceMap}
          title={`Source Map: ${title}`}
          showContributeBox={true}
          showDescription={true}
        />
      )}
    </div>
  )
}

export default Nodelet
