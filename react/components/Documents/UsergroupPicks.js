import React from 'react'
import WeblogViewer from '../Common/WeblogViewer'

const introContent = (
  <>
    <p>Some of Everything2's usergroups keep lists of writeups and documents particularly
    relevant to the group in question. These are listed below.</p>
    <p>You can also keep tabs on these using the Usergroup Writeups nodelet.
    Find out more about these and other usergroups at{' '}
    <a href="/title/Usergroup+Lineup">Usergroup Lineup</a>.</p>
  </>
)

const UsergroupPicks = ({ data }) => {
  return (
    <WeblogViewer
      pageTitle="Usergroup Picks"
      pageUrl="/title/Usergroup+Picks"
      backLinkText="[back to groups list]"
      introContent={introContent}
      data={data}
      emptyGroupMessage="No entries found for this group."
    />
  )
}

export default UsergroupPicks
