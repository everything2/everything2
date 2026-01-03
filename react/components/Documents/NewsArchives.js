import React from 'react'
import WeblogViewer from '../Common/WeblogViewer'

const NewsArchives = ({ data }) => {
  return (
    <WeblogViewer
      pageTitle="News Archives"
      pageUrl="/title/News+Archives"
      backLinkText="[back to archive menu]"
      data={data}
      emptyGroupMessage="No entries found for this archive."
    />
  )
}

export default NewsArchives
