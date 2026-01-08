import React from 'react'
import LinkNode from '../LinkNode'
import SourceMapDisplay from '../Developer/SourceMapDisplay'
import { FaList, FaCode, FaBell, FaInfoCircle, FaClock, FaShieldAlt } from 'react-icons/fa'

/**
 * Notification - Display page for notification nodes
 *
 * Notification nodes define types of notifications that appear in the
 * Notifications nodelet. They contain:
 * - description: Text shown in notification settings
 * - hourLimit: How long the notification stays visible (0 = never)
 * - code: Perl code to render the notification
 * - invalid_check: Perl code to check if notification should be hidden
 */
const Notification = ({ data, user }) => {
  if (!data || !data.notification) return null

  const { notification, sourceMap } = data
  const isDeveloper = user?.developer || user?.editor
  const {
    node_id,
    title,
    description,
    hourLimit,
    code_preview,
    invalid_check_preview
  } = notification

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

  // Format hour limit display
  const formatHourLimit = (hours) => {
    if (hours === 0 || hours === '0') return 'Never displays'
    if (hours === 1 || hours === '1') return '1 hour'
    return `${hours} hours`
  }

  const hourLimitBadgeColor = (hours) => {
    if (hours === 0 || hours === '0') return '#dc3545' // red - disabled
    if (hours <= 24) return '#28a745' // green - short duration
    if (hours <= 168) return '#ffc107' // yellow - medium (up to 1 week)
    return '#17a2b8' // blue - long duration
  }

  return (
    <div className="notification-display">
      {/* Quick Actions */}
      <div style={{ marginBottom: '20px' }}>
        <a
          href="/title/List%20Nodes%20of%20Type?setvars_ListNodesOfType_Type=notification"
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
          <FaList size={12} /> List All Notifications
        </a>
      </div>

      {/* About Section */}
      <div style={sectionStyle}>
        <h4 style={{ ...headerStyle, marginBottom: '15px', fontSize: '15px', borderBottom: '1px solid #dee2e6', paddingBottom: '10px' }}>
          <FaInfoCircle size={16} /> About Notifications
        </h4>
        <p style={{ ...valueStyle, lineHeight: '1.6', margin: 0 }}>
          Notification nodes define types of notifications that appear in the Notifications nodelet.
          Each notification has code to render it and an optional invalidation check. Users can
          configure which notifications they see via{' '}
          <LinkNode title="Notifications nodelet settings" type="htmlcode" />.
        </p>
        <p style={{ ...valueStyle, lineHeight: '1.6', marginTop: '10px', marginBottom: 0, color: '#f59e0b' }}>
          <strong>Security note:</strong> Changing the description may have implications for{' '}
          <LinkNode title="canseeNotification" type="htmlcode" /> security checks.
        </p>
      </div>

      {/* Description Section */}
      <div style={sectionStyle}>
        <h4 style={{ ...headerStyle, marginBottom: '15px', fontSize: '15px', borderBottom: '1px solid #dee2e6', paddingBottom: '10px' }}>
          <FaBell size={16} /> Description
        </h4>
        <div style={{ ...valueStyle, padding: '10px', backgroundColor: '#fff', border: '1px solid #dee2e6', borderRadius: '4px' }}>
          {description || <span style={emptyStyle}>No description defined</span>}
        </div>
        <p style={{ ...valueStyle, marginTop: '8px', marginBottom: 0, fontSize: '12px', color: '#6c757d' }}>
          This description is shown in the Notifications nodelet settings.
        </p>
      </div>

      {/* Configuration Section */}
      <div style={sectionStyle}>
        <h4 style={{ ...headerStyle, marginBottom: '15px', fontSize: '15px', borderBottom: '1px solid #dee2e6', paddingBottom: '10px' }}>
          <FaClock size={16} /> Time Limit
        </h4>

        <div>
          <div style={headerStyle}>
            <FaClock size={12} /> Maximum Hours
          </div>
          <div style={valueStyle}>
            <span style={{ ...badgeStyle, backgroundColor: hourLimitBadgeColor(hourLimit) }}>
              {formatHourLimit(hourLimit)}
            </span>
          </div>
          <p style={{ ...valueStyle, marginTop: '8px', marginBottom: 0, fontSize: '12px', color: '#6c757d' }}>
            How long this notification remains visible. Set to 0 to disable display entirely.
          </p>
        </div>
      </div>

      {/* Display Code Section (Developer only) */}
      {isDeveloper && code_preview && (
        <div style={sectionStyle}>
          <h4 style={{ ...headerStyle, marginBottom: '15px', fontSize: '15px', borderBottom: '1px solid #dee2e6', paddingBottom: '10px' }}>
            <FaCode size={16} /> Display Code
          </h4>
          <p style={{ ...valueStyle, marginBottom: '10px', fontSize: '12px', color: '#6c757d' }}>
            This Perl code renders the notification content.
          </p>
          <div style={codePreviewStyle}>
            {code_preview}
          </div>
        </div>
      )}

      {/* Invalid Check Code Section (Developer only) */}
      {isDeveloper && invalid_check_preview && (
        <div style={sectionStyle}>
          <h4 style={{ ...headerStyle, marginBottom: '15px', fontSize: '15px', borderBottom: '1px solid #dee2e6', paddingBottom: '10px' }}>
            <FaShieldAlt size={16} /> Invalidation Check
          </h4>
          <p style={{ ...valueStyle, marginBottom: '10px', fontSize: '12px', color: '#6c757d' }}>
            This Perl code determines if the notification should be hidden (e.g., if the triggering event no longer applies).
          </p>
          <div style={codePreviewStyle}>
            {invalid_check_preview}
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

export default Notification
