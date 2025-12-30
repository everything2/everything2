import React, { useState, useMemo } from 'react'
import { FaUserCog } from 'react-icons/fa'
import LinkNode from '../LinkNode'
import { renderE2Content } from '../Editor/E2HtmlSanitizer'
import MessageBox from '../MessageBox'
import UserToolsModal from '../UserToolsModal'

/**
 * UserDisplay - Display page for user nodes (homenodes)
 *
 * Migrated from Everything::Delegation::htmlpage::user_display_page
 * Preserves the legacy HTML structure: #homenodeheader, #homenodepicbox, #userinfo dl, etc.
 */
const UserDisplay = ({ data, e2 }) => {
  const [bookmarkSort, setBookmarkSort] = useState('nodename')
  const [bookmarkOrder, setBookmarkOrder] = useState('asc')
  const [isToolsModalOpen, setIsToolsModalOpen] = useState(false)

  // Helper to render E2 content with link parsing and HTML entity decoding
  const renderContent = (text) => {
    if (!text) return null
    const { html } = renderE2Content(text, { applyBreakTags: false })
    return <span dangerouslySetInnerHTML={{ __html: html }} />
  }

  if (!data || !data.user) return null

  const { user, viewer, is_own, is_ignored, message_count, recent_writeup_count, is_infected } = data

  // Sort bookmarks
  const sortedBookmarks = useMemo(() => {
    if (!user.bookmarks || user.bookmarks.length === 0) return []

    return [...user.bookmarks].sort((a, b) => {
      let comparison = 0
      if (bookmarkSort === 'nodename') {
        comparison = (a.title || '').toLowerCase().localeCompare((b.title || '').toLowerCase())
      } else if (bookmarkSort === 'tstamp') {
        comparison = (a.tstamp || '').localeCompare(b.tstamp || '')
      }
      return bookmarkOrder === 'desc' ? -comparison : comparison
    })
  }, [user.bookmarks, bookmarkSort, bookmarkOrder])

  const handleSort = (sortBy) => {
    if (bookmarkSort === sortBy) {
      setBookmarkOrder(bookmarkOrder === 'asc' ? 'desc' : 'asc')
    } else {
      setBookmarkSort(sortBy)
      setBookmarkOrder('asc')
    }
  }

  // Format relative time showing the highest significant unit
  // e.g., "32 seconds ago", "5 minutes ago", "3 hours ago", "2 days ago"
  const formatTimeSince = (isoDate) => {
    if (!isoDate) return null
    const date = new Date(isoDate)
    // Check for invalid date (epoch 0 or NaN)
    if (isNaN(date.getTime()) || date.getTime() <= 0) return null
    const now = new Date()
    const diffMs = now - date
    const diffSeconds = Math.floor(diffMs / 1000)
    const diffMinutes = Math.floor(diffMs / (1000 * 60))
    const diffHours = Math.floor(diffMs / (1000 * 60 * 60))
    const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24))
    const diffWeeks = Math.floor(diffDays / 7)
    const diffMonths = Math.floor(diffDays / 30)
    const diffYears = Math.floor(diffDays / 365)

    if (diffSeconds < 60) return diffSeconds === 1 ? '1 second ago' : `${diffSeconds} seconds ago`
    if (diffMinutes < 60) return diffMinutes === 1 ? '1 minute ago' : `${diffMinutes} minutes ago`
    if (diffHours < 24) return diffHours === 1 ? '1 hour ago' : `${diffHours} hours ago`
    if (diffDays < 7) return diffDays === 1 ? '1 day ago' : `${diffDays} days ago`
    if (diffWeeks < 4) return diffWeeks === 1 ? '1 week ago' : `${diffWeeks} weeks ago`
    if (diffMonths < 12) return diffMonths === 1 ? '1 month ago' : `${diffMonths} months ago`
    return diffYears === 1 ? '1 year ago' : `${diffYears} years ago`
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

  return (
    <div className="user-display">
      {/* Homenode header - matches legacy #homenodeheader */}
      <div id="homenodeheader" style={{ position: 'relative', paddingTop: (!viewer.is_guest && !is_own && (!user.hidemsgme || viewer.is_editor || viewer.is_chanop)) ? '30px' : undefined }}>
        {/* Message envelope and admin tools icons - show for logged-in users viewing other profiles */}
        {!viewer.is_guest && !is_own && (
          <div style={{ position: 'absolute', top: 0, right: 0, display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
            {/* Admin tools icon - for editors/chanops */}
            {(viewer.is_editor || viewer.is_chanop) && (
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
            {/* Message envelope */}
            {!user.hidemsgme && (
              <MessageBox recipientId={user.node_id} recipientTitle={user.title} showAsIcon={true} />
            )}
          </div>
        )}

        {/* Infected user warning - primitive bot detection, only visible to editors */}
        {Boolean(is_infected) && Boolean(viewer.is_editor) && (
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
                  <em>(Cure functionality available in legacy interface)</em>
                </p>
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
            <img src={`/${user.imgsrc}`} alt={`${user.title}'s image`} />
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

        {/* User info - matches legacy #userinfo dl from zenDisplayUserInfo */}
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
            {formatTimeSince(user.createtime) && (
              <> ({formatTimeSince(user.createtime)})</>
            )}
          </dd>

          {/* Last seen - respects hidelastseen unless viewer is editor */}
          {(!user.hidelastseen || viewer.is_editor) && user.lasttime && (
            <>
              <dt>last seen</dt>
              <dd>
                {formatDate(user.lasttime)}
                {formatTimeSince(user.lasttime) && (
                  <> ({formatTimeSince(user.lasttime)})</>
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
            {sortedBookmarks.map((bookmark) => (
              <li key={bookmark.node_id} data-tstamp={bookmark.tstamp} data-nodename={bookmark.title?.toLowerCase()}>
                <LinkNode nodeId={bookmark.node_id} title={bookmark.title} />
              </li>
            ))}
          </ul>
          <p>
            <a
              href="#"
              onClick={(e) => { e.preventDefault(); handleSort('nodename') }}
            >
              Sort by name
            </a>{' '}
            <a
              href="#"
              onClick={(e) => { e.preventDefault(); handleSort('tstamp') }}
            >
              Sort by date
            </a>
          </p>
        </div>
      )}

      {/* User Tools Modal - for editors/chanops */}
      {(viewer.is_editor || viewer.is_chanop) && (
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
