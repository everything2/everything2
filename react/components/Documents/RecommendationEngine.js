import React, { useState, useEffect, useCallback, useMemo } from 'react'

/**
 * RecommendationEngine - the two writeup recommendation documents, which run the same algorithm and
 * differ only by the initial "signal" (#4539). Both Pages are pure gates shipping only { type };
 * this component owns the copy (keyed on type) and fetches GET /api/recommendations?signal=….
 *
 *   do_you_c_what_i_c -> signal=cool     ("Do you C! what I C?")
 *   the_recommender   -> signal=bookmark ("The Recommender")
 *
 * Fetch-driven: reads cooluser/maxcools off the URL, fetches on mount, and the form refetches IN
 * PLACE (no full reload) syncing the URL via history.pushState.
 */
const REC_CONFIG = {
  do_you_c_what_i_c: {
    signal: 'cool',
    prefix: 'do-you-c',
    intro: null,
    sampleLine: "Picks up to 100 things you've cooled.",
    friendsLine: 'Finds everyone else who has cooled those things, too, then uses the top 20 of those (your "best friends.")',
    statsNoun: 'cooled writeups',
    noSignal: (pronoun) => (
      <>
        {pronoun} haven&apos;t cooled anything yet. Sorry - you might like to try{' '}
        <a href="/?node=The+Recommender">The Recommender</a>, which uses bookmarks, instead.
      </>
    )
  },
  the_recommender: {
    signal: 'bookmark',
    prefix: 'the-recommender',
    intro: (
      <>Takes the idea of <a href="/?node=Do+you+C!+what+I+C%3F">Do you C! what I C?</a> but pulls the user&apos;s bookmarks rather than C!s, so it&apos;s accessible to everyone.</>
    ),
    sampleLine: "Picks up to 100 things you've bookmarked.",
    friendsLine: 'Finds everyone else who has cooled those things, then uses the top 20 of those (your "best friends.")',
    statsNoun: 'bookmarked writeups',
    noSignal: (pronoun) => <>{pronoun} haven&apos;t bookmarked anything cool yet. Sorry.</>
  }
}

const paramsFromUrl = () => {
  const qs = new URLSearchParams(window.location.search)
  return { cooluser: qs.get('cooluser') || '', maxcools: qs.get('maxcools') || '10' }
}

const RecommendationEngine = ({ data }) => {
  const cfg = REC_CONFIG[data.type] || REC_CONFIG.do_you_c_what_i_c
  const p = cfg.prefix

  const initial = useMemo(paramsFromUrl, [])
  const [result, setResult] = useState(null)
  const [loading, setLoading] = useState(true)
  const [username, setUsername] = useState(initial.cooluser)
  const [maxCoolsInput, setMaxCoolsInput] = useState(initial.maxcools)

  const load = useCallback((params, { push } = {}) => {
    const api = new URLSearchParams({ signal: cfg.signal, maxcools: String(params.maxcools || 10) })
    if (params.cooluser) api.set('cooluser', params.cooluser)

    if (push) {
      const url = new URL(window.location.href)
      if (params.cooluser) url.searchParams.set('cooluser', params.cooluser)
      else url.searchParams.delete('cooluser')
      url.searchParams.set('maxcools', String(params.maxcools || 10))
      window.history.pushState({}, '', url.pathname + url.search)
    }

    setLoading(true)
    return fetch(`/api/recommendations?${api}`, { credentials: 'same-origin' })
      .then((r) => r.json())
      .then((j) => { setResult(j); setLoading(false) })
      .catch(() => setLoading(false))
  }, [cfg.signal])

  useEffect(() => {
    load(initial)
    const onPop = () => {
      const q = paramsFromUrl()
      setUsername(q.cooluser); setMaxCoolsInput(q.maxcools)
      load(q)
    }
    window.addEventListener('popstate', onPop)
    return () => window.removeEventListener('popstate', onPop)
  }, [load, initial])

  const onSubmit = (e) => {
    e.preventDefault()
    load({ cooluser: username, maxcools: maxCoolsInput }, { push: true })
  }

  const {
    state, recommendations = [], target_user, pronoun = 'You', maxcools = 10,
    num_signal_sampled = 0, num_friends = 0, target_username
  } = result || {}

  return (
    <div className={p}>
      <div className={`${p}__explanation`}>
        <h4 className={`${p}__heading`}>What It Does</h4>
        <ul className={`${p}__list`}>
          {cfg.intro && <li>{cfg.intro}</li>}
          <li>{cfg.sampleLine}</li>
          <li>{cfg.friendsLine}</li>
          <li>Finds the writeups that have been cooled by your &quot;best friends&quot; the most.</li>
          <li>Shows you the top 10 from that list that you haven&apos;t voted on and have less than {maxcools} C!s.</li>
        </ul>
      </div>

      <form onSubmit={onSubmit} className={`${p}__form`}>
        <div className={`${p}__form-group`}>
          <p>Or you can enter a user name to see what we think <em>they</em> would like:</p>
          <input
            type="text"
            name="cooluser"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            className={`${p}__text-input`}
            placeholder="username"
            size="15"
            maxLength="30"
          />
        </div>

        <div className={`${p}__form-group`}>
          <label className={`${p}__label`}>
            Maximum C!s per writeup:{' '}
            <input
              type="number"
              name="maxcools"
              value={maxCoolsInput}
              onChange={(e) => setMaxCoolsInput(e.target.value)}
              className={`${p}__number-input`}
              min="1"
              max="100"
            />
          </label>
        </div>

        <button type="submit" className={`${p}__button`}>
          Find Recommendations
        </button>
      </form>

      {loading && <p className={`${p}__info`}>Loading...</p>}

      {!loading && state === 'user_not_found' && (
        <p className={`${p}__error`}>Sorry, no &apos;{target_username}&apos; is found on the system!</p>
      )}

      {!loading && state === 'system_error' && (
        <p className={`${p}__error`}>A system error occurred. Please try again later.</p>
      )}

      {!loading && state === 'no_signal' && (
        <p className={`${p}__info`}>{cfg.noSignal(pronoun)}</p>
      )}

      {!loading && state === 'no_friends' && (
        <p className={`${p}__info`}>{pronoun} don&apos;t have any &apos;best friends&apos; yet. Sorry.</p>
      )}

      {!loading && !state && recommendations.length === 0 && num_signal_sampled > 0 && (
        <p className={`${p}__info`}>
          No new recommendations found that match your criteria. Try increasing the maximum C!s allowed.
        </p>
      )}

      {!loading && recommendations.length > 0 && (
        <div className={`${p}__results`}>
          <p className={`${p}__stats-info`}>
            Based on {num_signal_sampled} {cfg.statsNoun} and {num_friends} similar users:
          </p>
          <div className={`${p}__recommendation-list`}>
            {recommendations.map((rec) => (
              <div key={rec.node_id} className={`${p}__recommendation`}>
                <a href={`/?node_id=${rec.parent_id}`} className={`${p}__parent-link`}>{rec.parent_title}</a>
                {' '}
                (<a href={`/?node_id=${rec.node_id}`} className={`${p}__writeup-link`}>{rec.title}</a>)
                {' '}
                <span className={`${p}__cool-count`}>[{rec.cooled} C!{rec.cooled !== 1 ? 's' : ''}]</span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}

export default RecommendationEngine
