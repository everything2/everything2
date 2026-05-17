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
 * Styles are in CSS classes (notification-display__*)
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

  // Format hour limit display
  const formatHourLimit = (hours) => {
    if (hours === 0 || hours === '0') return 'Never displays'
    if (hours === 1 || hours === '1') return '1 hour'
    return `${hours} hours`
  }

  const getHourLimitBadgeClass = (hours) => {
    if (hours === 0 || hours === '0') return 'notification-display__badge--disabled'
    if (hours <= 24) return 'notification-display__badge--short'
    if (hours <= 168) return 'notification-display__badge--medium'
    return 'notification-display__badge--long'
  }

  return (
    <div className="notification-display">
      {/* Quick Actions */}
      <div className="notification-display__actions">
        <a
          href="/title/List%20Nodes%20of%20Type?setvars_ListNodesOfType_Type=notification"
          className="notification-display__action-btn"
        >
          <FaList size={12} /> List All Notifications
        </a>
      </div>

      {/* About Section */}
      <div className="notification-display__section">
        <h4 className="notification-display__section-header">
          <FaInfoCircle size={16} /> About Notifications
        </h4>
        <p className="notification-display__text">
          Notification nodes define types of notifications that appear in the Notifications nodelet.
          Each notification has code to render it and an optional invalidation check. Users can
          configure which notifications they see via{' '}
          <LinkNode title="Notifications nodelet settings" type="htmlcode" />.
        </p>
        <p className="notification-display__text notification-display__text--note">
          <strong>Security note:</strong> Changing the description may have implications for{' '}
          <LinkNode title="canseeNotification" type="htmlcode" /> security checks.
        </p>
      </div>

      {/* Description Section */}
      <div className="notification-display__section">
        <h4 className="notification-display__section-header">
          <FaBell size={16} /> Description
        </h4>
        <div className="notification-display__value-box">
          {description || <span className="notification-display__empty">No description defined</span>}
        </div>
        <p className="notification-display__help-text">
          This description is shown in the Notifications nodelet settings.
        </p>
      </div>

      {/* Configuration Section */}
      <div className="notification-display__section">
        <h4 className="notification-display__section-header">
          <FaClock size={16} /> Time Limit
        </h4>

        <div>
          <div className="notification-display__header">
            <FaClock size={12} /> Maximum Hours
          </div>
          <div className="notification-display__value">
            <span
              className={`notification-display__badge ${getHourLimitBadgeClass(hourLimit)}`}
            >
              {formatHourLimit(hourLimit)}
            </span>
          </div>
          <p className="notification-display__help-text">
            How long this notification remains visible. Set to 0 to disable display entirely.
          </p>
        </div>
      </div>

      {/* Display Code Section (Developer only) */}
      {isDeveloper && code_preview && (
        <div className="notification-display__section">
          <h4 className="notification-display__section-header">
            <FaCode size={16} /> Display Code
          </h4>
          <p className="notification-display__code-help">
            This Perl code renders the notification content.
          </p>
          <div className="notification-display__code-preview">
            {code_preview}
          </div>
        </div>
      )}

      {/* Invalid Check Code Section (Developer only) */}
      {isDeveloper && invalid_check_preview && (
        <div className="notification-display__section">
          <h4 className="notification-display__section-header">
            <FaShieldAlt size={16} /> Invalidation Check
          </h4>
          <p className="notification-display__code-help">
            This Perl code determines if the notification should be hidden (e.g., if the triggering event no longer applies).
          </p>
          <div className="notification-display__code-preview">
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
