import React from 'react'
import LinkNode from '../LinkNode'
import SourceMapDisplay from '../Developer/SourceMapDisplay'
import { FaList, FaCode, FaTrophy, FaInfoCircle, FaTag, FaCheck, FaTimes } from 'react-icons/fa'

/**
 * Achievement - Display page for achievement nodes
 *
 * Achievements are badges/rewards that users can earn by completing
 * various tasks or milestones on the site. They contain:
 * - display: The text shown when achievement is displayed
 * - achievement_type: Category of achievement
 * - subtype: Sub-category for ordered checking
 * - achievement_still_available: Whether new users can earn it
 * - code: Perl code that checks if user has earned the achievement
 */
const Achievement = ({ data, user }) => {
  if (!data || !data.achievement) return null

  const { achievement, sourceMap } = data
  const isDeveloper = user?.developer || user?.editor
  const {
    node_id,
    title,
    display,
    achievement_type,
    subtype,
    achievement_still_available,
    code_preview
  } = achievement

  return (
    <div className="achievement-display">
      {/* Quick Actions */}
      <div className="achievement__actions">
        <a
          href="/title/List%20Nodes%20of%20Type?setvars_ListNodesOfType_Type=achievement"
          className="achievement__action-btn"
        >
          <FaList size={12} /> List All Achievements
        </a>
      </div>

      {/* About Section */}
      <div className="achievement__section">
        <h4 className="achievement__section-title">
          <FaInfoCircle size={16} /> About Achievements
        </h4>
        <p className="achievement__value achievement__about">
          Achievements are badges that users earn by completing various tasks or reaching
          milestones on the site. Each achievement has code that determines whether a user
          has earned it. Achievements of the same subtype are checked in title order, stopping
          at the first unearned one.
        </p>
      </div>

      {/* Display Text Section */}
      <div className="achievement__section">
        <h4 className="achievement__section-title">
          <FaTrophy size={16} /> Display Text
        </h4>
        <div className="achievement__value achievement__value--padded">
          {display || <span className="achievement__empty">No display text defined</span>}
        </div>
      </div>

      {/* Configuration Section */}
      <div className="achievement__section">
        <h4 className="achievement__section-title">
          <FaTag size={16} /> Configuration
        </h4>

        <div className="achievement__grid">
          <div>
            <div className="achievement__header">
              <FaTag size={12} /> Type
            </div>
            <div className="achievement__value">
              {achievement_type ? (
                <span className="achievement__badge">{achievement_type}</span>
              ) : (
                <span className="achievement__empty">Not specified</span>
              )}
            </div>
          </div>

          <div>
            <div className="achievement__header">
              <FaTag size={12} /> Subtype
            </div>
            <div className="achievement__value">
              {subtype ? (
                <span className="achievement__badge">{subtype}</span>
              ) : (
                <span className="achievement__empty">Not specified</span>
              )}
            </div>
          </div>

          <div>
            <div className="achievement__header">
              {achievement_still_available ? <FaCheck size={12} /> : <FaTimes size={12} />} Availability
            </div>
            <div className="achievement__value">
              <span className={`achievement__badge ${achievement_still_available ? 'achievement__badge--available' : 'achievement__badge--unavailable'}`}>
                {achievement_still_available ? 'Still Available' : 'No Longer Available'}
              </span>
            </div>
          </div>
        </div>
      </div>

      {/* Code Preview Section (Developer only) */}
      {isDeveloper && code_preview && (
        <div className="achievement__section">
          <h4 className="achievement__section-title">
            <FaCode size={16} /> Code Preview
          </h4>
          <p className="achievement__code-hint">
            This Perl code determines whether a user has earned this achievement.
            See <LinkNode title="achievementsByType" type="htmlcode" /> for how achievements are checked.
          </p>
          <div className="achievement__code">
            {code_preview}
          </div>
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

export default Achievement
