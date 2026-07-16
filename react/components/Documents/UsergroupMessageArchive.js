import React, { useState, useEffect, useCallback, useMemo } from 'react'
import LinkNode from '../LinkNode'

/**
 * UsergroupMessageArchive - View archived messages sent to usergroups.
 * Styles in CSS: .usergroup-archive__*
 *
 * Fully client-resolved (#4541): the Page is a pure gate. Fetches GET
 * /api/usergroup_message_archive (list) on mount, reading viewgroup/max_show/startnum off the URL;
 * the group picker + pagination refetch IN PLACE (no reload) via history.pushState. Copy-to-inbox +
 * the reset-time preference POST to /api/usergroup_message_archive/copy (#4472), unchanged.
 */
const GUEST_COPY = 'You must login to use this feature.'
const ERROR_COPY = {
  no_such_group: 'There is no such usergroup.',
  not_member: "You aren't a member of this group, so you can't view the group's messages.",
  no_archive: "This group doesn't archive messages."
}

const paramsFromUrl = () => {
  const qs = new URLSearchParams(window.location.search)
  return {
    viewgroup: qs.get('viewgroup') || '',
    max_show: qs.get('max_show') || '',
    startnum: qs.get('startnum') || ''
  }
}

const UsergroupMessageArchive = ({ user }) => {
  const nodeId = (typeof window !== 'undefined' && window.e2 && window.e2.node_id) || ''
  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)

  const load = useCallback((params, { push } = {}) => {
    const api = new URLSearchParams()
    if (params.viewgroup) api.set('viewgroup', params.viewgroup)
    if (params.max_show) api.set('max_show', params.max_show)
    if (params.startnum !== undefined && params.startnum !== '') api.set('startnum', String(params.startnum))

    if (push) {
      const url = new URL(window.location.href)
      for (const k of ['viewgroup', 'max_show', 'startnum']) {
        if (params[k] !== undefined && params[k] !== '') url.searchParams.set(k, String(params[k]))
        else url.searchParams.delete(k)
      }
      window.history.pushState({}, '', url.pathname + url.search)
    }

    setLoading(true)
    return fetch(`/api/usergroup_message_archive?${api}`, { credentials: 'same-origin' })
      .then((r) => r.json())
      .then((j) => { setData(j); setLoading(false) })
      .catch(() => setLoading(false))
  }, [])

  useEffect(() => {
    load(paramsFromUrl())
    const onPop = () => load(paramsFromUrl())
    window.addEventListener('popstate', onPop)
    return () => window.removeEventListener('popstate', onPop)
  }, [load])

  const isAdmin = !!user?.admin

  if (loading && !data) {
    return <div className="usergroup-archive"><p>Loading...</p></div>
  }

  const { state, archive_groups = [], selected_group, messages, total_messages, show_start, max_show, num_show, reset_time } = data || {}

  if (state === 'guest') {
    return (
      <div className="usergroup-archive">
        <p className="usergroup-archive__see-also">See also <LinkNode title="Usergroup discussions" /></p>
        <p>If you are a member of one of these groups, you can view messages sent to the group.</p>
        <p>{GUEST_COPY}</p>
      </div>
    )
  }

  const errorText = state && ERROR_COPY[state]

  const pickGroup = (title) => (e) => { e.preventDefault(); load({ viewgroup: title }, { push: true }) }
  const paginate = (startnum) => load({ viewgroup: selected_group.title, startnum }, { push: true })

  return (
    <div className="usergroup-archive">
      <p className="usergroup-archive__see-also">See also <LinkNode title="Usergroup discussions" /></p>

      <p>If you are a member of one of these groups, you can view messages sent to the group.</p>

      {isAdmin && (
        <p>
          You can edit the usergroups that have messages archived at{' '}
          <a href="?node=usergroup+message+archive+manager&type=restricted_superdoc" className="usergroup-archive__link">
            usergroup message archive manager
          </a>.
        </p>
      )}

      <p>
        To view messages sent to a group, choose one of the following groups.
        You can only see the messages if the group has the feature enabled, and you&apos;re a member of the group.
        <br />
        Choose from:{' '}
        {archive_groups.map((g, idx) => (
          <span key={g.node_id}>
            {idx > 0 && ', '}
            <a href={`?node_id=${nodeId}&viewgroup=${encodeURIComponent(g.title)}`} onClick={pickGroup(g.title)} className="usergroup-archive__link">
              {g.title}
            </a>
          </span>
        ))}
      </p>

      {errorText && <p className="usergroup-archive__error">{errorText}</p>}

      {selected_group && !errorText && messages && (
        <MessageDisplay
          selectedGroup={selected_group}
          messages={messages}
          totalMessages={total_messages}
          showStart={show_start}
          maxShow={max_show}
          numShow={num_show}
          resetTime={reset_time}
          onPaginate={paginate}
        />
      )}
    </div>
  )
}

const MessageDisplay = ({ selectedGroup, messages, totalMessages, showStart, maxShow, numShow, resetTime: initialResetTime, onPaginate }) => {
  const startDefault = Math.max(0, totalMessages - maxShow)

  const [checked, setChecked] = useState({})
  const [resetTime, setResetTime] = useState(!!initialResetTime)
  const [copiedCount, setCopiedCount] = useState(0)
  const [banner, setBanner] = useState('')
  const [loading, setLoading] = useState(false)

  const toggleMsg = (id) => setChecked((prev) => ({ ...prev, [id]: !prev[id] }))

  const handleCopy = async (e) => {
    e.preventDefault()
    const messageIds = Object.keys(checked).filter((id) => checked[id]).map(Number)
    setLoading(true)
    setBanner('')
    try {
      const res = await fetch('/api/usergroup_message_archive/copy', {
        method: 'POST',
        credentials: 'same-origin',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify({ group: selectedGroup.title, message_ids: messageIds, reset_time: resetTime ? 1 : 0 })
      })
      const json = res.ok ? await res.json() : null
      if (json && json.success) {
        setCopiedCount(json.copied_count)
        setChecked({})
      } else {
        setBanner((json && json.error) || 'Copy failed.')
      }
    } catch (err) {
      setBanner(err.message || 'Copy failed.')
    } finally {
      setLoading(false)
    }
  }

  // Pagination descriptors; inactive ones carry a startnum the caller refetches in place.
  const genPaginationData = () => {
    const links = []
    if (showStart !== 0) {
      const limitU = Math.min(maxShow, totalMessages)
      links.push({ label: `first ${maxShow} (1-${limitU})`, startnum: 0, active: false })
    } else {
      links.push({ label: `first ${maxShow}`, active: true })
    }
    if (showStart > 0) {
      const limitL = Math.max(1, showStart - maxShow)
      const limitU = Math.min(limitL + maxShow, totalMessages)
      links.push({ label: `previous (${limitL}-${limitU - 1})`, startnum: showStart - maxShow, active: false })
    } else {
      links.push({ label: 'previous', active: true })
    }
    links.push({ label: `current (${showStart + 1}-${showStart + numShow})`, active: true, current: true })
    if (showStart < startDefault) {
      let limitU = showStart + maxShow + maxShow
      limitU = Math.min(limitU, totalMessages)
      let limitL = limitU - maxShow + 1
      limitL = Math.max(1, limitL)
      limitL = Math.min(limitL, startDefault + 1)
      links.push({ label: `next (${limitL}-${limitU})`, startnum: limitL - 1, active: false })
    } else {
      links.push({ label: 'next', active: true })
    }
    if (showStart < startDefault) {
      links.push({ label: `last ${maxShow} (${startDefault + 1}-${totalMessages})`, startnum: startDefault, active: false })
    } else {
      links.push({ label: `last ${maxShow}`, active: true })
    }
    return links
  }

  const paginationLinks = totalMessages > messages.length ? genPaginationData() : []

  return (
    <form onSubmit={handleCopy}>
      <p>Viewing messages for group <LinkNode id={selectedGroup.node_id} display={selectedGroup.title} />:</p>

      <label className="usergroup-archive__checkbox">
        <input type="checkbox" checked={resetTime} onChange={(e) => setResetTime(e.target.checked)} />
        Keep original send date (instead of using &quot;now&quot; time)
      </label>
      <br />

      {copiedCount > 0 && (
        <p className="usergroup-archive__copied-msg">
          (Copied {copiedCount} group message{copiedCount === 1 ? '' : 's'} to self.)
        </p>
      )}

      {banner && <p className="usergroup-archive__error">{banner}</p>}

      {numShow > 0 && (
        <p>Showing {numShow} message{numShow === 1 ? '' : 's'} (number {showStart + 1} to {showStart + numShow}) out of a total of {totalMessages}.</p>
      )}

      <table className="usergroup-archive__table">
        <thead>
          <tr>
            <th className="usergroup-archive__th--cp">cp</th>
            <th className="usergroup-archive__th--num">#</th>
            <th className="usergroup-archive__th">author</th>
            <th className="usergroup-archive__th">time</th>
            <th className="usergroup-archive__th">message</th>
          </tr>
        </thead>
        <tbody>
          {messages.map((msg) => (
            <tr key={msg.message_id}>
              <td className="usergroup-archive__td--cp">
                <input type="checkbox" checked={!!checked[msg.message_id]} onChange={() => toggleMsg(msg.message_id)} />
              </td>
              <td className="usergroup-archive__td--num">({msg.number})</td>
              <td className="usergroup-archive__td--small">
                {msg.author_id ? <LinkNode id={msg.author_id} display={msg.author_title} /> : '?'}
              </td>
              <td className="usergroup-archive__td--time">{msg.timestamp}</td>
              <td className="usergroup-archive__td" dangerouslySetInnerHTML={{ __html: msg.text }} />
            </tr>
          ))}
        </tbody>
        <tfoot>
          <tr>
            <td colSpan="5" className="usergroup-archive__td">
              Checking the box in the &quot;cp&quot; column will <strong>c</strong>o<strong>p</strong>y the message[s] to your private message box
            </td>
          </tr>
        </tfoot>
      </table>

      {paginationLinks.length > 0 && (
        <div className="usergroup-archive__pagination">
          {paginationLinks.map((link, idx) => (
            <span key={idx}>
              {idx > 0 && '   '}
              [ {link.active ? (
                <span className={link.current ? 'usergroup-archive__current-link' : undefined}>{link.label}</span>
              ) : (
                <a href="#" className="usergroup-archive__link"
                   onClick={(e) => { e.preventDefault(); onPaginate(link.startnum) }}>
                  {link.label}
                </a>
              )} ]
            </span>
          ))}
        </div>
      )}

      <div className="usergroup-archive__submit-section">
        <button type="submit" className="usergroup-archive__button" disabled={loading}>
          {loading ? 'Copying…' : 'Copy selected messages'}
        </button>
      </div>
    </form>
  )
}

export default UsergroupMessageArchive
