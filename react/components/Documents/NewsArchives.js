import React, { useState, useEffect, useCallback } from 'react'
import WeblogViewer from '../Common/WeblogViewer'

/**
 * NewsArchives - browse the webloggable news archives (thin shell over WeblogViewer).
 *
 * Fully client-resolved (#4543): the Page is a pure gate. Fetches GET /api/news_archives on mount,
 * reading view_weblog off the URL; the group-select + back link refetch IN PLACE (no reload) via
 * history.pushState, using WeblogViewer's optional onSelectGroup/onBack callbacks.
 */
const viewWeblogFromUrl = () => (new URLSearchParams(window.location.search).get('view_weblog') || '')

const PERMISSION_ERROR = 'You do not have permission to view this group.'
const CONFIG_ERROR = 'Configuration not found'

const NewsArchives = ({ user }) => {
  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)
  const isAdmin = !!user?.admin

  const load = useCallback((viewWeblog, { push } = {}) => {
    const api = new URLSearchParams()
    if (viewWeblog) api.set('view_weblog', String(viewWeblog))

    if (push) {
      const url = new URL(window.location.href)
      if (viewWeblog) url.searchParams.set('view_weblog', String(viewWeblog))
      else url.searchParams.delete('view_weblog')
      window.history.pushState({}, '', url.pathname + url.search)
    }

    setLoading(true)
    return fetch(`/api/news_archives?${api}`, { credentials: 'same-origin' })
      .then((r) => r.json())
      .then((j) => { setData(j); setLoading(false) })
      .catch(() => setLoading(false))
  }, [])

  useEffect(() => {
    load(viewWeblogFromUrl())
    const onPop = () => load(viewWeblogFromUrl())
    window.addEventListener('popstate', onPop)
    return () => window.removeEventListener('popstate', onPop)
  }, [load])

  if (loading && !data) {
    return <div className="weblog-viewer"><p>Loading...</p></div>
  }

  // Map the API's error states to the copy WeblogViewer renders via data.error.
  const errorCopy = data?.state === 'permission' ? PERMISSION_ERROR
    : data?.state === 'no_config' ? CONFIG_ERROR
      : undefined

  return (
    <WeblogViewer
      pageTitle="News Archives"
      pageUrl="/title/News+Archives"
      backLinkText="[back to archive menu]"
      data={{ ...data, isAdmin, error: errorCopy }}
      emptyGroupMessage="No entries found for this archive."
      onSelectGroup={(nodeId) => load(nodeId, { push: true })}
      onBack={() => load('', { push: true })}
    />
  )
}

export default NewsArchives
