import React, { useState } from 'react'

/**
 * MarkAllDiscussionsAsRead - Mark all debates/discussions as read
 *
 * CE members mark CE debates read; admins can also mark admin debates read.
 * Each button POSTs to /api/markdiscussionsread/{ce,admin} (#4410) instead of a
 * GET link that marked debates read inside the page controller on render.
 */
const MarkAllDiscussionsAsRead = ({ data, user }) => {
  const { error } = data

  // Viewer role flag comes from the global e2.user prop (#4390 dedup)
  const isAdmin = !!user?.admin

  const [ceDone, setCeDone] = useState(false)
  const [ceCount, setCeCount] = useState(0)
  const [adminDone, setAdminDone] = useState(false)
  const [adminCount, setAdminCount] = useState(0)
  const [busy, setBusy] = useState(null) // 'ce' | 'admin' | null
  const [apiError, setApiError] = useState(null)

  const mark = async (which, onDone) => {
    setBusy(which)
    setApiError(null)
    try {
      const res = await fetch(`/api/markdiscussionsread/${which}`, {
        method: 'POST',
        credentials: 'same-origin',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: '{}',
      })
      const result = res.ok ? await res.json() : null
      if (result && result.success) {
        onDone(result.count || 0)
      } else {
        setApiError((result && result.error) || 'Action failed')
      }
    } catch (err) {
      setApiError(err.message || 'Action failed')
    } finally {
      setBusy(null)
    }
  }

  if (error) {
    return <div className="error-message">{error}</div>
  }

  return (
    <div className="mark-discussions-read">
      {apiError && <p className="mark-discussions__error">{apiError}</p>}

      {!ceDone ? (
        <div className="mark-discussions__section">
          <p>
            Apply pressure to the hypertext if you want to mark all of your old
            CE debates as read (and the new ones too, everything!).
          </p>
          <p className="mark-discussions__link">
            <button
              type="button"
              className="mark-discussions__button"
              onClick={() => mark('ce', (count) => { setCeDone(true); setCeCount(count) })}
              disabled={busy === 'ce'}
            >
              {busy === 'ce' ? 'Marking…' : 'Mark CE Debates as Read'}
            </button>
          </p>
        </div>
      ) : (
        <p>
          It is done. All of your CE debates have been marked as read
          ({ceCount} updated). Hopefully there's never a reason to do this again.
        </p>
      )}

      {isAdmin && (!adminDone ? (
        <div className="mark-discussions__admin-section">
          <p>
            It appears you are like a god amongst men. You may do the same but to
            your admin debates.
          </p>
          <p className="mark-discussions__link">
            <button
              type="button"
              className="mark-discussions__button"
              onClick={() => mark('admin', (count) => { setAdminDone(true); setAdminCount(count) })}
              disabled={busy === 'admin'}
            >
              {busy === 'admin' ? 'Marking…' : 'Mark Admin Debates as Read'}
            </button>
          </p>
        </div>
      ) : (
        <p className="mark-discussions__done">
          It is done. All of your admin debates have been marked as read
          ({adminCount} updated). Hopefully there's never a reason to do this again.
        </p>
      ))}
    </div>
  )
}

export default MarkAllDiscussionsAsRead
