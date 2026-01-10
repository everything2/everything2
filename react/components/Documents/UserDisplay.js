import React, { useState } from 'react'
import { FaUserCog, FaHandHoldingHeart, FaStar, FaRegStar } from 'react-icons/fa'
import LinkNode from '../LinkNode'
import { renderE2Content } from '../Editor/E2HtmlSanitizer'
import MessageBox from '../MessageBox'
import UserToolsModal from '../UserToolsModal'
import TimeSince from '../TimeSince'

/**
 * UserDisplay - Display page for user nodes (homenodes)
 *
 * Migrated from Everything::Delegation::htmlpage::user_display_page
 * Preserves the legacy HTML structure: #homenodeheader, #homenodepicbox, #userinfo dl, etc.
 */
const UserDisplay = ({ data, e2 }) => {
  const [isToolsModalOpen, setIsToolsModalOpen] = useState(false)
  const [isFavorited, setIsFavorited] = useState(data?.is_favorited || false)
  const [favoriteLoading, setFavoriteLoading] = useState(false)
  const [isInfected, setIsInfected] = useState(data?.is_infected || false)
  const [cureLoading, setCureLoading] = useState(false)
  const [cureMessage, setCureMessage] = useState(null)

  // Helper to render E2 content with link parsing and HTML entity decoding
  const renderContent = (text) => {
    if (!text) return null
    const { html } = renderE2Content(text, { applyBreakTags: false })
    return <span dangerouslySetInnerHTML={{ __html: html }} />
  }

  if (!data || !data.user) return null

  const { user, viewer, is_own, is_ignored, message_count, recent_writeup_count, is_infected } = data

  // Check if a date is valid for display
  const isValidDate = (isoDate) => {
    if (!isoDate) return false
    const date = new Date(isoDate)
    return !isNaN(date.getTime()) && date.getTime() > 0
  }

  const formatDate = (isoDate) => {
    if (!isoDate) return <em>forever</em>
    const date = new Date(isoDate)
    // Check for invalid date (epoch 0 or NaN)
    if (isNaN(date.getTime()) || date.getTime() <= 0) return <em>forever</em>
    return date.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    })
  }

  // Handle favorite/unfavorite toggle
  const handleFavoriteToggle = async () => {
    if (favoriteLoading) return
    setFavoriteLoading(true)

    try {
      const action = isFavorited ? 'unfavorite' : 'favorite'
      const response = await fetch(`/api/favorites/${user.node_id}/action/${action}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' }
      })
      const result = await response.json()
      if (result.success) {
        setIsFavorited(result.is_favorited)
      }
    } catch (err) {
      console.error('Failed to toggle favorite:', err)
    } finally {
      setFavoriteLoading(false)
    }
  }

  // Handle cure infection (admin only)
  const handleCureInfection = async () => {
    if (cureLoading) return
    setCureLoading(true)
    setCureMessage(null)

    try {
      const response = await fetch('/api/user/cure', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ user_id: user.node_id })
      })
      const result = await response.json()
      if (result.success) {
        setIsInfected(false)
        setCureMessage('Infection cured successfully')
      } else {
        setCureMessage(result.error || 'Failed to cure infection')
      }
    } catch (err) {
      console.error('Failed to cure infection:', err)
      setCureMessage('Network error while curing infection')
    } finally {
      setCureLoading(false)
    }
  }

  // Determine if we should show the icon row
  const showIconRow = !viewer.is_guest && (
    !is_own || // Always show for other users
    Boolean(viewer.is_editor || viewer.is_chanop || viewer.is_admin) // Show for admins on own profile
  )

  return (
    <div className="user-display">
      {/* Homenode header - matches legacy #homenodeheader */}
      <div id="homenodeheader" style={{ position: 'relative', paddingTop: showIconRow ? '30px' : undefined }}>
        {/* Icon row - admin tools, favorite, sanctify, message */}
        {showIconRow && (
          <div style={{ position: 'absolute', top: 0, right: 0, display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
            {/* Admin tools icon - for editors/chanops/admins (including on own profile) */}
            {(viewer.is_editor || viewer.is_chanop || viewer.is_admin) && (
              <button
                onClick={() => setIsToolsModalOpen(true)}
                className="user-tools-trigger"
                title="User Tools"
                style={{
                  background: 'none',
                  border: 'none',
                  cursor: 'pointer',
                  color: '#4060b0',
                  fontSize: '1.2rem',
                  padding: '0.25rem',
                  display: 'flex',
                  alignItems: 'center'
                }}
              >
                <FaUserCog />
              </button>
            )}
            {/* Favorite icon - for logged-in users viewing other profiles */}
            {!is_own && (
              <button
                onClick={handleFavoriteToggle}
                disabled={favoriteLoading}
                title={isFavorited ? `Stop notifications for ${user.title}'s writeups` : `Get notifications for ${user.title}'s writeups`}
                style={{
                  background: 'none',
                  border: 'none',
                  cursor: favoriteLoading ? 'wait' : 'pointer',
                  color: isFavorited ? '#f59e0b' : '#4060b0',
                  fontSize: '1.2rem',
                  padding: '0.25rem',
                  display: 'flex',
                  alignItems: 'center',
                  opacity: favoriteLoading ? 0.5 : 1
                }}
              >
                {isFavorited ? <FaStar /> : <FaRegStar />}
              </button>
            )}
            {/* Sanctify icon - for Level 11+ users or editors viewing other profiles */}
            {!is_own && (viewer.is_editor || (e2?.user?.level >= 11)) && (
              <a
                href={`/title/Sanctify%20user?recipient=${encodeURIComponent(user.title)}`}
                title={`Sanctify ${user.title}`}
                style={{
                  color: '#4060b0',
                  fontSize: '1.2rem',
                  padding: '0.25rem',
                  display: 'flex',
                  alignItems: 'center',
                  textDecoration: 'none'
                }}
              >
                <FaHandHoldingHeart />
              </a>
            )}
            {/* Message envelope - for other profiles only */}
            {!is_own && !user.hidemsgme && (
              <MessageBox recipientId={user.node_id} recipientTitle={user.title} showAsIcon={true} />
            )}
          </div>
        )}

        {/* Infected user warning - primitive bot detection, only visible to editors */}
        {Boolean(isInfected) && Boolean(viewer.is_editor) && (
          <div id="homenode_infection" className="warning">
            <div>
              <img src="/static/biohazard.png" alt="Biohazard Sign" title="User is infected" />
              <p>
                This user is{' '}
                <LinkNode type="oppressor_superdoc" title="Infected Users" display="infected" />.
              </p>
            </div>
            {viewer.is_admin && (
              <div>
                <img src="/static/physician.png" alt="Physician Sign" />
                <p>
                  <button
                    onClick={handleCureInfection}
                    disabled={cureLoading}
                    style={{
                      background: '#4060b0',
                      color: 'white',
                      border: 'none',
                      padding: '0.5rem 1rem',
                      borderRadius: '4px',
                      cursor: cureLoading ? 'wait' : 'pointer',
                      opacity: cureLoading ? 0.7 : 1
                    }}
                  >
                    {cureLoading ? 'Curing...' : 'Cure Infection'}
                  </button>
                </p>
                {cureMessage && (
                  <p style={{ marginTop: '0.5rem', fontStyle: 'italic' }}>
                    {cureMessage}
                  </p>
                )}
              </div>
            )}
          </div>
        )}

        {/* Account lock warning for editors */}
        {user.acctlock && viewer.is_editor && (
          <p>
            <big><strong>Account locked</strong></big> by{' '}
            <LinkNode nodeId={user.acctlock.node_id} title={user.acctlock.title} />
          </p>
        )}

        {/* User image box - matches legacy #homenodepicbox */}
        <div id="homenodepicbox">
          {user.imgsrc && (
            <img
              src={`https://s3-us-west-2.amazonaws.com/hnimagew.everything2.com/${user.title.replace(/\W/g, '_')}`}
              alt={`${user.title}'s image`}
              id="userimage"
            />
          )}

          {/* Edit link for own profile */}
          {Boolean(is_own) && (
            <p>
              <a
                href={`/user/${encodeURIComponent(user.title)}?displaytype=edit`}
                id="usereditlink"
              >
                (edit user information)
              </a>
            </p>
          )}
        </div>

        {/* User info */}
        <dl id="userinfo">
          {/* Message forward alias */}
          {user.message_forward_to && (
            <>
              <dt>is a messaging forward for</dt>
              <dd>
                <LinkNode
                  nodeId={user.message_forward_to.node_id}
                  title={user.message_forward_to.title}
                />
              </dd>
            </>
          )}

          {/* User since */}
          <dt>user since</dt>
          <dd>
            {formatDate(user.createtime)}
            {isValidDate(user.createtime) && (
              <> (<TimeSince timestamp={user.createtime} />)</>
            )}
          </dd>

          {/* Last seen - respects hidelastseen unless viewer is editor */}
          {(!user.hidelastseen || viewer.is_editor) && user.lasttime && (
            <>
              <dt>last seen</dt>
              <dd>
                {formatDate(user.lasttime)}
                {isValidDate(user.lasttime) && (
                  <> (<TimeSince timestamp={user.lasttime} />)</>
                )}
              </dd>
            </>
          )}

          {/* Number of writeups */}
          <dt>number of write-ups</dt>
          <dd>
            <a href={`/user/${encodeURIComponent(user.title)}/writeups`} style={{ fontSize: 'inherit' }}>
              {user.numwriteups}
            </a>
          </dd>

          {/* Recent writeups (if enabled) */}
          {recent_writeup_count !== undefined && (
            <>
              <dt>number of write-ups within last year</dt>
              <dd>{recent_writeup_count || <em>none!</em>}</dd>
            </>
          )}

          {/* Level / Experience */}
          <dt>level / experience</dt>
          <dd>
            {user.leveltitle} ({user.level}) / {user.experience} XP
          </dd>

          {/* GP - only for self or admin */}
          {(Boolean(is_own) || Boolean(viewer.is_admin)) && user.GP !== undefined && (
            <>
              <dt>GP</dt>
              <dd>{user.GP}</dd>
            </>
          )}

          {/* C!s spent */}
          {user.cools_spent > 0 && (
            <>
              <dt>C!s spent</dt>
              <dd>
                <LinkNode
                  type="superdoc"
                  title="Cool Archive"
                  params={{ foruser: user.title }}
                  display={String(user.cools_spent)}
                />
              </dd>
            </>
          )}

          {/* Mission drive - only show if non-empty */}
          {user.mission && user.mission.trim() && (
            <>
              <dt>mission drive within everything</dt>
              <dd>{renderContent(user.mission)}</dd>
            </>
          )}

          {/* Specialties - only show if non-empty */}
          {user.specialties && user.specialties.trim() && (
            <>
              <dt>specialties</dt>
              <dd>{renderContent(user.specialties)}</dd>
            </>
          )}

          {/* School/company - only show if non-empty */}
          {user.employment && user.employment.trim() && (
            <>
              <dt>school/company</dt>
              <dd>{renderContent(user.employment)}</dd>
            </>
          )}

          {/* Motto - only show if non-empty */}
          {user.motto && user.motto.trim() && (
            <>
              <dt>motto</dt>
              <dd>{renderContent(user.motto)}</dd>
            </>
          )}

          {/* Usergroup memberships */}
          {user.groups && user.groups.length > 0 && (
            <>
              <dt>member of</dt>
              <dd>
                {user.groups.map((group, index) => (
                  <React.Fragment key={group.node_id}>
                    {index > 0 && ', '}
                    <LinkNode type="usergroup" title={group.title} />
                  </React.Fragment>
                ))}
              </dd>
            </>
          )}

          {/* Categories maintained */}
          {user.categories && user.categories.length > 0 && (
            <>
              <dt>categories maintained</dt>
              <dd>
                {user.categories.map((cat, index) => (
                  <React.Fragment key={cat.node_id}>
                    {index > 0 && ', '}
                    <LinkNode nodeId={cat.node_id} title={cat.title} />
                  </React.Fragment>
                ))}
              </dd>
            </>
          )}

          {/* Most recent writeup */}
          {user.lastnoded && user.lastnoded.e2node && (
            <>
              <dt>most recent writeup</dt>
              <dd>
                <LinkNode
                  nodeId={user.lastnoded.writeup.node_id}
                  title={user.lastnoded.e2node.title}
                />
              </dd>
            </>
          )}

          {/* Drafts link */}
          {!viewer.is_guest && (
            <>
              <dt>things in progress</dt>
              <dd>
                {is_own ? (
                  <LinkNode type="superdoc" title="Drafts" display="Your drafts" />
                ) : (
                  <LinkNode
                    type="superdoc"
                    title="Drafts"
                    params={{ other_user: user.title }}
                    display={`${user.title}'s drafts`}
                  />
                )}
              </dd>
            </>
          )}

          {/* Messages from this user */}
          {!viewer.is_guest && message_count > 0 && (
            <>
              <dt>{is_own ? 'talking to yourself' : '/msgs from me'}</dt>
              <dd>
                <LinkNode
                  type="superdoc"
                  title="message inbox"
                  params={{ fromuser: user.title }}
                  display={`${message_count} message${message_count === 1 ? '' : 's'}`}
                />
              </dd>
            </>
          )}
        </dl>
      </div>

      <hr className="clear" />

      {/* Homenode text content */}
      <table width="100%" id="homenodetext">
        <tbody>
          <tr>
            <td>
              {/* Registration entries (profile data) */}
              {!viewer.is_guest && !is_ignored && user.registrations && user.registrations.length > 0 && (
                <table className="registries">
                  <tbody>
                    {user.registrations.map((reg, index) => (
                      <tr key={index}>
                        <td>
                          <LinkNode
                            nodeId={reg.registry.node_id}
                            title={reg.registry.title}
                          />
                        </td>
                        <td>{renderContent(reg.data)}</td>
                        <td>{renderContent(reg.comments)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}

              {/* User bio (doctext) */}
              <div className="content">
                {user.doctext ? (
                  <div dangerouslySetInnerHTML={{ __html: renderE2Content(user.doctext).html }} />
                ) : (
                  <p><em>This user has not written a bio yet.</em></p>
                )}
              </div>
            </td>
          </tr>
        </tbody>
      </table>

      {/* Bookmarks */}
      {user.bookmarks && user.bookmarks.length > 0 && (
        <div className="bookmarks-section">
          <h2>Bookmarks</h2>
          <ul className="linklist" id="bookmarklist">
            {user.bookmarks.map((bookmark) => (
              <li key={bookmark.node_id}>
                <LinkNode nodeId={bookmark.node_id} title={bookmark.title} />
              </li>
            ))}
          </ul>
        </div>
      )}

      {/* User Tools Modal - for editors/chanops/admins (including on own profile) */}
      {Boolean(viewer.is_editor || viewer.is_chanop || viewer.is_admin) && (
        <UserToolsModal
          user={user}
          viewer={viewer}
          isOpen={isToolsModalOpen}
          onClose={() => setIsToolsModalOpen(false)}
        />
      )}
    </div>
  )
}

export default UserDisplay
