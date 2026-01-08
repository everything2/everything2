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

  const sectionStyle = {
    marginBottom: '20px',
    padding: '15px',
    backgroundColor: '#f8f9fa',
    borderRadius: '6px',
    border: '1px solid #dee2e6'
  }

  const headerStyle = {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
    marginBottom: '10px',
    color: '#38495e',
    fontSize: '14px',
    fontWeight: 'bold'
  }

  const valueStyle = {
    color: '#495057',
    fontSize: '13px'
  }

  const emptyStyle = {
    color: '#6c757d',
    fontStyle: 'italic',
    fontSize: '13px'
  }

  const codePreviewStyle = {
    fontFamily: 'monospace',
    fontSize: '12px',
    backgroundColor: '#1e1e1e',
    color: '#d4d4d4',
    padding: '12px',
    borderRadius: '4px',
    overflow: 'auto',
    maxHeight: '300px',
    whiteSpace: 'pre-wrap',
    wordBreak: 'break-all'
  }

  const badgeStyle = {
    display: 'inline-block',
    padding: '3px 8px',
    backgroundColor: '#6c757d',
    color: 'white',
    borderRadius: '3px',
    fontSize: '12px',
    fontWeight: '500'
  }

  const availabilityBadgeStyle = {
    ...badgeStyle,
    backgroundColor: achievement_still_available ? '#28a745' : '#dc3545'
  }

  return (
    <div className="achievement-display">
      {/* Quick Actions */}
      <div style={{ marginBottom: '20px' }}>
        <a
          href="/title/List%20Nodes%20of%20Type?setvars_ListNodesOfType_Type=achievement"
          style={{
            display: 'inline-flex',
            alignItems: 'center',
            gap: '6px',
            padding: '8px 16px',
            backgroundColor: '#4060b0',
            color: 'white',
            textDecoration: 'none',
            borderRadius: '4px',
            fontSize: '13px',
            fontWeight: '500'
          }}
        >
          <FaList size={12} /> List All Achievements
        </a>
      </div>

      {/* About Section */}
      <div style={sectionStyle}>
        <h4 style={{ ...headerStyle, marginBottom: '15px', fontSize: '15px', borderBottom: '1px solid #dee2e6', paddingBottom: '10px' }}>
          <FaInfoCircle size={16} /> About Achievements
        </h4>
        <p style={{ ...valueStyle, lineHeight: '1.6', margin: 0 }}>
          Achievements are badges that users earn by completing various tasks or reaching
          milestones on the site. Each achievement has code that determines whether a user
          has earned it. Achievements of the same subtype are checked in title order, stopping
          at the first unearned one.
        </p>
      </div>

      {/* Display Text Section */}
      <div style={sectionStyle}>
        <h4 style={{ ...headerStyle, marginBottom: '15px', fontSize: '15px', borderBottom: '1px solid #dee2e6', paddingBottom: '10px' }}>
          <FaTrophy size={16} /> Display Text
        </h4>
        <div style={{ ...valueStyle, padding: '10px', backgroundColor: '#fff', border: '1px solid #dee2e6', borderRadius: '4px' }}>
          {display || <span style={emptyStyle}>No display text defined</span>}
        </div>
      </div>

      {/* Configuration Section */}
      <div style={sectionStyle}>
        <h4 style={{ ...headerStyle, marginBottom: '15px', fontSize: '15px', borderBottom: '1px solid #dee2e6', paddingBottom: '10px' }}>
          <FaTag size={16} /> Configuration
        </h4>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '15px' }}>
          <div>
            <div style={headerStyle}>
              <FaTag size={12} /> Type
            </div>
            <div style={valueStyle}>
              {achievement_type ? (
                <span style={badgeStyle}>{achievement_type}</span>
              ) : (
                <span style={emptyStyle}>Not specified</span>
              )}
            </div>
          </div>

          <div>
            <div style={headerStyle}>
              <FaTag size={12} /> Subtype
            </div>
            <div style={valueStyle}>
              {subtype ? (
                <span style={badgeStyle}>{subtype}</span>
              ) : (
                <span style={emptyStyle}>Not specified</span>
              )}
            </div>
          </div>

          <div>
            <div style={headerStyle}>
              {achievement_still_available ? <FaCheck size={12} /> : <FaTimes size={12} />} Availability
            </div>
            <div style={valueStyle}>
              <span style={availabilityBadgeStyle}>
                {achievement_still_available ? 'Still Available' : 'No Longer Available'}
              </span>
            </div>
          </div>
        </div>
      </div>

      {/* Code Preview Section (Developer only) */}
      {isDeveloper && code_preview && (
        <div style={sectionStyle}>
          <h4 style={{ ...headerStyle, marginBottom: '15px', fontSize: '15px', borderBottom: '1px solid #dee2e6', paddingBottom: '10px' }}>
            <FaCode size={16} /> Code Preview
          </h4>
          <p style={{ ...valueStyle, marginBottom: '10px', fontSize: '12px', color: '#6c757d' }}>
            This Perl code determines whether a user has earned this achievement.
            See <LinkNode title="achievementsByType" type="htmlcode" /> for how achievements are checked.
          </p>
          <div style={codePreviewStyle}>
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
