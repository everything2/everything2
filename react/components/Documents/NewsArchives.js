import React from 'react'
import WeblogViewer from '../Common/WeblogViewer'

const NewsArchives = ({ data, user }) => {
  const isAdmin = !!user?.admin
  return (
    <WeblogViewer
      pageTitle="News Archives"
      pageUrl="/title/News+Archives"
      backLinkText="[back to archive menu]"
      data={{ ...data, isAdmin }}
      emptyGroupMessage="No entries found for this archive."
    />
  )
}

export default NewsArchives
