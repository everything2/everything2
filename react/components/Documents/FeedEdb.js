import React, { useState } from 'react'

/**
 * FeedEdb - Admin tool for simulating EDB borg status.
 * Styles in CSS: .feed-edb__*
 * The borg/unborg action POSTs to /api/feed_edb/borg and updates inline (#4390 → API);
 * the page controller is now pure-render (no more ?numborgings= page reload).
 */
const FeedEdb = ({ data, user }) => {
  const { message, current_count, borg_options = [] } = data

  const isAdmin = !!user?.admin
  const [count, setCount] = useState(current_count)
  const [resultMsg, setResultMsg] = useState('')
  const [busy, setBusy] = useState(false)

  if (!isAdmin) {
    return (
      <div className="feed-edb">
        <p>{message}</p>
      </div>
    )
  }

  const handleBorg = async (n) => {
    setBusy(true)
    setResultMsg('')
    try {
      const res = await fetch('/api/feed_edb/borg', {
        method: 'POST',
        credentials: 'same-origin',
        headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
        body: JSON.stringify({ numborgings: n }),
      })
      const result = res.ok ? await res.json() : null
      if (result && result.success) {
        setResultMsg(result.message)
        setCount(result.current_count)
      } else {
        setResultMsg((result && result.error) || 'EDB is unreachable right now.')
      }
    } catch (err) {
      setResultMsg('Failed to reach EDB.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="feed-edb">
      <p>
        <strong>Your current borged count:</strong> {count}
      </p>

      <div className="feed-edb__instructions">
        <p>
          This is mainly for the 3 of us that need to play with EDB.
        </p>
        <p>
          Er, that doesn&apos;t quite sound the way I meant it. How about &quot;...want to
          experiment with EDB&quot;.
        </p>
        <p>
          Mmmmm, that isn&apos;t quite what I meant, either. Lets try: &quot;...want to have
          EDB eat them&quot;.
        </p>
        <p>Argh, I give up.</p>

        <div className="feed-edb__options-row">
          <code>numborgings = ( </code>
          {borg_options.map((opt, idx) => (
            <span key={opt}>
              {idx > 0 && ', '}
              <button
                type="button"
                disabled={busy}
                onClick={() => handleBorg(opt)}
                className="feed-edb__option-link"
              >
                {opt}
              </button>
            </span>
          ))}
          <code> );</code>
        </div>

        {resultMsg && (
          <p className="feed-edb__action-result">{resultMsg}</p>
        )}
      </div>
    </div>
  )
}

export default FeedEdb
